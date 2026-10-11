"""Exercise the test fixture on actual loopback TCP without starting a game."""
import socket
import struct
import threading
import time
import unittest
from jitter_proxy import JitterProxy


def exact(stream, length):
    data = b''
    while len(data) < length:
        chunk = stream.recv(length - len(data))
        if not chunk:
            raise EOFError('Truncated local test message')
        data += chunk
    return data


class RelayTest(unittest.TestCase):
    def test_real_frames_keep_bytes_and_order_across_delays(self):
        packets = [b'hello', '加入侧暂停'.encode(), bytes(range(256)) * 1200, b'last']
        listener = socket.socket()
        listener.bind(('127.0.0.1', 0))
        listener.listen(1)
        listener.settimeout(5)
        received, errors = [], []

        def server():
            try:
                stream, _ = listener.accept()
                with stream:
                    stream.settimeout(5)
                    for _ in packets:
                        size = struct.unpack('>I', exact(stream, 4))[0]
                        payload = exact(stream, size)
                        received.append(payload)
                        # Split the length header too, to exercise stream framing.
                        header = struct.pack('>I', len(payload))
                        stream.sendall(header[:1])
                        stream.sendall(header[1:] + payload)
                    exact(stream, 1)  # Keep relay endpoints alive until the caller verifies.
            except (OSError, EOFError) as error:
                errors.append(str(error))

        worker = threading.Thread(target=server)
        relay = JitterProxy(listener.getsockname()[1], [40, 0, 15, 0])
        worker.start()
        relay.start()
        try:
            with socket.create_connection(('127.0.0.1', relay.port), timeout=5) as client:
                began = time.monotonic()
                for packet in packets:
                    client.sendall(struct.pack('>I', len(packet)) + packet)
                actual = [exact(client, struct.unpack('>I', exact(client, 4))[0]) for _ in packets]
                self.assertEqual(packets, received)
                self.assertEqual(packets, actual)
                self.assertGreaterEqual(time.monotonic() - began, .07)
                report = relay.stop()
                self.assertIsNone(report['error'])
                for direction in report['directions'].values():
                    self.assertEqual(direction['received'], 4)
                    self.assertEqual(direction['sent'], 4)
                    self.assertEqual(direction['pending'], 0)
                    self.assertGreaterEqual(direction['delay_ms_max'], 39)
        finally:
            if relay.thread.is_alive():
                relay.stop()
            listener.close()
            worker.join(timeout=6)
        self.assertFalse(worker.is_alive())

    def test_invalid_schedule_is_rejected_before_listening(self):
        for schedule in ([], [-1], [451], [1.5], [True]):
            with self.assertRaises(ValueError):
                JitterProxy(12345, schedule)


if __name__ == '__main__':
    unittest.main()
