
import json
import os
from pathlib import Path
import pwd
import re
import sys
import uuid


class AuthError(Exception):
    pass


def libraries():
    try:
        import gi
        gi.require_version("NM", "1.0")
        from gi.repository import Gio, GLib, NM
        return Gio, GLib, NM
    except (ImportError, ValueError):
        raise AuthError("toolsMissing") from None


def profile_for(client, device, ssid):
    profiles = []
    for profile in client.get_connections():
        wireless = profile.get_setting_wireless()
        security = profile.get_setting_wireless_security()
        if not wireless or not security or security.get_key_mgmt() not in ("wpa-eap", "ieee8021x"):
            continue
        name = wireless.get_ssid()
        if name and bytes(name.get_data()) == ssid.encode() and device.connection_valid(profile):
            profiles.append(profile)
    return max(profiles, key=lambda profile: profile.get_setting_connection().get_timestamp(), default=None)


def describe(profile):
    eap = profile.get_setting_802_1x() if profile else None
    return dict(profile=bool(profile), username=eap.get_identity() or "" if eap else "",
                method=eap.get_eap_method(0) if eap and eap.get_num_eap_methods() else "peap",
                inner=eap.get_phase2_auth() or "mschapv2" if eap else "mschapv2",
                domain=eap.get_domain_suffix_match() or eap.get_domain_match() or "" if eap else "",
                certificate=eap.get_ca_cert_path() or "" if eap and eap.get_ca_cert_scheme() == 2 else "")


def connection_for(request, profile, GLib, NM):
    username = str(request.get("username", "")).strip()
    password = request.get("password", "")
    if not username or not isinstance(password, str) or not password or "\x00" in username + password:
        raise AuthError("credentialsRequired")
    connection = NM.SimpleConnection.new_clone(profile) if profile else NM.SimpleConnection.new()
    if profile:
        eap = connection.get_setting_802_1x()
        if not eap or not eap.get_num_eap_methods() or eap.get_eap_method(0) not in ("peap", "ttls", "pwd"):
            raise AuthError("unsupportedMethod")
    else:
        method = request.get("method", "peap")
        inner = request.get("inner", "mschapv2")
        if method not in ("peap", "ttls") or inner not in (("mschapv2", "gtc") if method == "peap" else ("pap", "mschapv2")):
            raise AuthError("unsupportedMethod")
        domain = str(request.get("domain", "")).strip()
        if domain:
            try:
                domain = domain.rstrip(".").encode("idna").decode("ascii").lower()
            except UnicodeError:
                raise AuthError("invalidDomain") from None
            if len(domain) > 253 or "." not in domain or not all(re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?", label) for label in domain.split(".")):
                raise AuthError("invalidDomain")
        settings = NM.SettingConnection.new()
        settings.set_property("id", request["ssid"])
        settings.set_property("uuid", str(uuid.uuid4()))
        settings.set_property("type", "802-11-wireless")
        settings.set_property("interface-name", request["interface"])
        settings.add_permission("user", pwd.getpwuid(os.getuid()).pw_name, None)
        connection.add_setting(settings)
        wireless = NM.SettingWireless.new()
        wireless.set_property("ssid", GLib.Bytes.new(request["ssid"].encode()))
        wireless.set_property("mode", "infrastructure")
        connection.add_setting(wireless)
        security = NM.SettingWirelessSecurity.new()
        security.set_property("key-mgmt", "wpa-eap")
        connection.add_setting(security)
        eap = NM.Setting8021x.new()
        eap.add_eap_method(method)
        eap.set_property("phase2-auth", inner)
        if domain:
            eap.set_property("domain-suffix-match", domain)
        certificate = str(request.get("certificate", "")).strip()
        if certificate:
            path = Path(certificate).expanduser()
            if not path.is_absolute() or not path.is_file():
                raise AuthError("invalidCertificate")
            eap.set_property("ca-cert", GLib.Bytes.new(("file://" + str(path) + "\x00").encode()))
        else:
            eap.set_property("system-ca-certs", True)
        connection.add_setting(eap)
        connection.add_setting(NM.SettingIP4Config.new())
        connection.get_setting_ip4_config().set_property("method", "auto")
        connection.add_setting(NM.SettingIP6Config.new())
        connection.get_setting_ip6_config().set_property("method", "auto")
    eap.set_property("identity", username)
    eap.set_property("password", password)
    eap.set_property("password-flags", NM.SettingSecretFlags.NONE)
    connection.verify()
    return connection


def perform(request):
    Gio, GLib, NM = libraries()
    client = NM.Client.new(None)
    device = client.get_device_by_iface(request.get("interface", ""))
    ssid = request.get("ssid", "")
    if not device or not isinstance(ssid, str) or not ssid:
        raise AuthError("unavailable")
    access_point = max((ap for ap in device.get_access_points() if ap.get_ssid() and bytes(ap.get_ssid().get_data()) == ssid.encode()), key=lambda ap: ap.get_strength(), default=None)
    if not access_point:
        raise AuthError("unavailable")
    profile = profile_for(client, device, ssid)
    if request.get("action") == "inspect":
        return describe(profile)
    if request.get("action") != "connect":
        raise AuthError("invalidRequest")
    connection = connection_for(request, profile, GLib, NM)
    loop = GLib.MainLoop()
    cancellable = Gio.Cancellable.new()
    outcome = dict(ok=False, error="connectionFailed")
    active = None
    saving = False

    def finish(ok):
        outcome["ok"] = ok
        loop.quit()

    def state_changed(current, *args):
        nonlocal saving
        state = current.get_state()
        if state == NM.ActiveConnectionState.ACTIVATED:
            if profile:
                finish(True)
            elif not saving:
                saving = True
                current.get_connection().commit_changes_async(True, cancellable, saved)
        elif state == NM.ActiveConnectionState.DEACTIVATED:
            finish(False)

    def saved(source, result, *args):
        try:
            source.commit_changes_finish(result)
            finish(True)
        except GLib.Error:
            outcome["error"] = "saveFailed"
            finish(False)

    def activated(source, result, *args):
        nonlocal active
        try:
            active = source.activate_connection_finish(result) if profile else source.add_and_activate_connection2_finish(result)[0]
            active.connect("notify::state", state_changed)
            state_changed(active)
        except GLib.Error:
            finish(False)

    def updated(source, result, *args):
        try:
            source.update2_finish(result)
            client.activate_connection_async(profile, device, access_point.get_path(), cancellable, activated)
        except GLib.Error:
            finish(False)

    def timeout():
        outcome["error"] = "connectionTimeout"
        cancellable.cancel()
        finish(False)
        return GLib.SOURCE_REMOVE

    timer = GLib.timeout_add_seconds(55, timeout)
    if profile:
        profile.update2(connection.to_dbus(NM.ConnectionSerializationFlags.ALL), NM.SettingsUpdate2Flags.TO_DISK, None, cancellable, updated)
    else:
        client.add_and_activate_connection2(connection, device, access_point.get_path(), GLib.Variant("a{sv}", {"persist": GLib.Variant("s", "volatile")}), cancellable, activated)
    loop.run()
    if not cancellable.is_cancelled():
        GLib.source_remove(timer)
    return outcome


def main():
    if sys.argv[1:] == ["--check"]:
        libraries()
        return
    if sys.argv[1:]:
        raise AuthError("invalidRequest")
    request = json.loads(sys.stdin.readline(65536))
    if not isinstance(request, dict):
        raise AuthError("invalidRequest")
    print(json.dumps(perform(request)))


if __name__ == "__main__":
    try:
        main()
    except AuthError as error:
        print(json.dumps(dict(ok=False, error=str(error))))
        sys.exit(1)
    except Exception:
        print(json.dumps(dict(ok=False, error="connectionFailed")))
        sys.exit(1)
