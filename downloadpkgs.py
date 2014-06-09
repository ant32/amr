#!/usr/bin/env python2
import httplib
from threading import Thread, RLock
from Queue import Queue

print "Downloading:"
lock = RLock()

def worker(conn):
    while True:
        pkg = q.get()
        with lock:
            print pkg
        conn.request('GET', '/packages/{0}/{1}/PKGBUILD'.format(pkg[:2], pkg))
        resp = conn.getresponse()
        data = resp.read()
        with open("build/pkgbuilds/{0}".format(pkg), 'wb') as f:
            f.write(data)
        q.task_done()

q = Queue()
for i in range(8):
     conn = httplib.HTTPSConnection("aur.archlinux.org")
     t = Thread(target=worker,args=(conn,))
     t.daemon = True
     t.start()

f = open("buildlist.txt", "r")
for pkg in f:
    pkg = pkg[:-1]
    if pkg[0] != "#":
        q.put(pkg)

q.join() 
