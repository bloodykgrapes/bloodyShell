pragma Singleton

import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

Singleton
{
    id: translation

    readonly property string folder: Paths.shellDir + "/translations"

    property var languages: []

    readonly property string systemLanguage:
    {
        const code = String(Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "en").split(/[_.@]/)[0].toLowerCase();
        return languages.some(l => l.code === code) ? code : "en";
    }
    readonly property string language: Config.shellLanguage === "system" ? systemLanguage
                                     : languages.some(l => l.code === Config.shellLanguage) ? Config.shellLanguage : "en"

    readonly property var locale: Qt.locale(language === "en" ? "en_US" : language)

    property var strings: ({})
    property var english: ({})

    function tr(key)
    {
        const s = strings, e = english;
        return s[key] || e[key] || key;
    }

    FolderListModel
    {
        id: files
        folder: "file://" + translation.folder
        nameFilters: ["*.json"]
        showDirs: false
    }

    Instantiator
    {
        model: files
        delegate: FileView
        {
            required property string fileName
            required property string filePath
            path: filePath
            printErrors: false
            onLoaded: translation.register(fileName.replace(/\.json$/, ""), text())
        }
    }

    property var found: ({})
    function register(code, text)
    {
        let data;
        try { data = JSON.parse(text) } catch (e) { console.warn("Translation: " + code + ".json:", e); return }
        const all = Object.assign({}, found);
        all[code] = { code: code, name: data.name || code, english: data.english || data.name || code };
        found = all;
        languages = Object.keys(all).sort((a, b) => a === "en" ? -1 : b === "en" ? 1 : a.localeCompare(b)).map(k => all[k]);
    }

    component Strings: FileView
    {
        required property string code
        signal parsed(var strings)

        path: code !== "" ? translation.folder + "/" + code + ".json" : ""
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded:
        {
            try { parsed(JSON.parse(text()).strings || {}) }
            catch (e) { console.warn("Translation:", e); parsed({}) }
        }
        onLoadFailed: parsed({})
    }

    Strings { code: translation.language; onParsed: s => translation.strings = s }
    Strings { code: "en"; onParsed: s => translation.english = s }
}
