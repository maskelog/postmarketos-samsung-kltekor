date
ps -o pid,ppid,comm,args | grep -v '\['
cat /etc/greetd/config.toml
python3 - <<'PY'
p=open('/dev/vcsa1','rb').read()
c=p[1]
t=p[4::2].decode('ascii','replace')
lines=[t[i:i+c].rstrip() for i in range(0,len(t),c)]
print('\n'.join(lines)[-6000:])
PY
