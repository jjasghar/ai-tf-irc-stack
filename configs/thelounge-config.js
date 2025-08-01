"use strict";

module.exports = {
    public: true,
    host: "127.0.0.1",
    port: 9000,
    bind: undefined,
    reverseProxy: true,
    maxHistory: 10000,
    https: {
        enable: false,
        key: "",
        certificate: "",
        ca: ""
    },
    theme: "default",
    prefetch: false,
    prefetchStorage: false,
    prefetchMaxImageSize: 2048,
    prefetchMaxSearchSize: 50,
    prefetchTimeout: 5000,
    fileUpload: {
        enable: false,
        maxFileSize: 10240,
        baseUrl: null
    },
    transports: ["polling", "websocket"],
    leaveMessage: "The Lounge - https://thelounge.chat",
    defaults: {
        name: "{ergo_network}",
        host: "127.0.0.1",
        port: 6667,
        password: "",
        tls: false,
        rejectUnauthorized: false,
        nick: "GuestUser",
        username: "GuestUser",
        realname: "GuestUser",
        join: "#lobby"
    },
    displayNetwork: true,
    lockNetwork: false,
    messageStorage: ["sqlite", "text"],
    useHexIp: false,
    webirc: null,
    identd: {
        enable: false,
        port: 113
    },
    oidentd: null,
//    ldap: {
//        enable: false,
//        url: "ldaps://example.com",
//        tlsOptions: {},
//        primaryKey: "uid",
//        searchDN: {
//            rootDN: "ou=accounts,dc=example,dc=com",
//            rootPassword: "1234",
//            filter: "(&(objectClass=account)(uid=%uid))"
//        }
//    },
    debug: {
        ircFramework: false,
        raw: false
    }
};