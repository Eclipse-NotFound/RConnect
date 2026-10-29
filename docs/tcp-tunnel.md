# Remote co-op through a TCP tunnel

**English** · [简体中文](tcp-tunnel.zh-CN.md)

For RConnect A **0.2.24-tcp1**, Windows / Remains 1.02. Both players install the same version and restart. The tunnel forwards your teammate's connection to the host's game; RConnect does not provide an account, public node or server.

## Setup

Load both characters before connecting. If the host uses game port **23456** and the tunnel service assigns **node.example.net:45678**:

| Where | Value |
|---|---|
| Host RConnect port | `23456`, then click **Host** |
| Tunnel type | **TCP** |
| Tunnel local address | `127.0.0.1`, when the tunnel client runs on the host PC |
| Tunnel local port | `23456`, matching the game |
| Tunnel external/remote port | The assigned `45678`; it need not match the local port |
| Joining RConnect address | Paste `node.example.net:45678`, then click **Join** |

Replace the example endpoint with the actual one supplied by your tunnel service. RConnect separates the hostname and port, then fills both fields. It also accepts `tcp://node.example.net:45678`, or a hostname and separate port. An explicit port in the address takes precedence. Creating a room uses only the local port field; the host address field does not set the listening address.

Keep both the host game and tunnel running. With ordinary TCP forwarding, the joining player only needs the game. **A remote friend must not enter 127.0.0.1**: it means their own computer.

## SakuraFrp and frp

For SakuraFrp, create a TCP tunnel with the local address/port above, start it, and share the connection endpoint from its log. See [SakuraFrp's game guide](https://doc.natfrp.com/game/other-games.html) (Chinese).

For an already configured and authenticated frp client, add this proxy section to `frpc.toml`. Your frps server must allow the chosen remote port:

```toml
[[proxies]]
name = "rconnect"
type = "tcp"
localIP = "127.0.0.1"
localPort = 23456
remotePort = 45678
```

The joining player uses the frps public hostname/IP and port `45678`. This is only the proxy section; it does not provision a server or include your account credentials. See [frp TCP forwarding](https://gofrp.org/en/docs/features/tcp-udp/).

Use plain TCP forwarding. **Disable Proxy Protocol**: its extra header is not part of the game's protocol. Do not select HTTP, HTTPS or UDP tunnels, or paste a web address into RConnect. See [frp proxy configuration](https://gofrp.org/en/docs/reference/proxy/).

## Troubleshooting and limits

1. Confirm the host clicked **Host**, and the game's port matches the tunnel's local port.
2. Confirm the tunnel is online. A local-service connection error points to the host game/address/port.
3. Use the assigned external port on the joining side, which may differ from the host's local port.
4. If the tunnel connects but the game handshake fails, check matching mod versions and ensure no Proxy Protocol or web-proxy layer is enabled.

RConnect currently has no room password or application-level end-to-end encryption. Share the endpoint only with a trusted teammate. For persistent public access, restrict sources or use private access features offered by the tunnel service. Never share your service token or paste it into the game.

The release passed real local TCP relay tests with separate ports, DNS, pasted UI addresses, Unicode chat and game-state packets. A second run added 40 ms in each direction and fragmented writes. This does **not** qualify a real public node, second broadband connection or long-distance session. IPv6 input parsing was checked, but an IPv6 tunnel was not tested. Added latency and insufficient bandwidth can worsen existing dense-scene, projectile and room-loading stalls.
