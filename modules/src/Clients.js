.pragma library

function update(clients, client, active)
{
    active = active === true;
    if (clients.includes(client) === active) return clients;
    return active ? clients.concat([client]) : clients.filter(item => item !== client);
}
