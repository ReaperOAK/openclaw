// Force IPv4 fallback timeout to 2s (default 250ms is too short on networks
// where IPv6 is resolved but not routed, causing ETIMEDOUT before fallback).
// See: https://github.com/nodejs/node/issues/54359
import * as net from "node:net";

net.setDefaultAutoSelectFamily(true);
net.setDefaultAutoSelectFamilyAttemptTimeout(2000);
