"""Owned loopback TCP forwarder; optional per-direction latency and split writes."""
import collections,select,socket,threading,time
class Relay:
    def __init__(self,target,delay=0):
        self.target=target;self.delay=delay;self.stop=threading.Event();self.errors=[]
        self.counts={'join_to_host':0,'host_to_join':0};self.writes=0;self.connections=0
        self.listener=socket.socket();self.listener.bind(('127.0.0.1',0));self.listener.listen();self.listener.settimeout(.2)
        self.port=self.listener.getsockname()[1];self.thread=threading.Thread(target=self.run,daemon=True);self.thread.start()
    def run(self):
        while not self.stop.is_set():
            try:client,_=self.listener.accept()
            except socket.timeout:continue
            except OSError:break
            upstream=None
            try:
                upstream=socket.create_connection(('127.0.0.1',self.target),5);self.connections+=1
                sockets=[client,upstream];queues={s:collections.deque() for s in sockets}
                for s in sockets:s.setblocking(False)
                while not self.stop.is_set():
                    reads,writes,_=select.select(sockets,[s for s in sockets if queues[s] and queues[s][0][0]<=time.monotonic()],[],.003)
                    closed=False
                    for s in reads:
                        data=s.recv(65536)
                        if not data:closed=True;break
                        key='join_to_host' if s is client else 'host_to_join';self.counts[key]+=len(data)
                        queues[upstream if s is client else client].append([time.monotonic()+self.delay,memoryview(data)])
                    if closed:break
                    for s in writes:
                        item=queues[s][0];limit=(1,3,17,65536)[self.writes%4] if self.delay else 65536
                        try:n=s.send(item[1][:limit])
                        except BlockingIOError:continue
                        self.writes+=1;item[1]=item[1][n:]
                        if not item[1]:queues[s].popleft()
            except (ConnectionResetError,ConnectionAbortedError,BrokenPipeError):pass
            except Exception as e:self.errors.append(repr(e))
            finally:
                client.close()
                if upstream:upstream.close()
    def close(self):
        self.stop.set();self.listener.close();self.thread.join(3)
        return dict(target=self.target,external=self.port,delay_each_direction_ms=self.delay*1000,counts=self.counts,writes=self.writes,connections=self.connections,errors=self.errors,stopped=not self.thread.is_alive())
