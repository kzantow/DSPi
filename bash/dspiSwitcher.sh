#!/bin/bash
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
killall -9 amsynth
killall -9 guitarix
killall -9 a2jmidid
killall -9 jackd
killall -9 a2jmidid

# This checks to see if an arguement was passed in. This overwrites the dspi environment variable
if [ "${#1}" -gt "0" ]; then
  dspi=$1
fi

[ $dspi == 'guitarix' ] && (
  jackd -s -S -P80 -p16 -t2000 -dalsa -dhw:pisound -r48000 -p128 -n3 -s -D -Xnone >> /home/pi/DSPi/jackboot.log &
  # chrt -a -r -p 80 $! &
  sleep 15
  guitarix --nogui -t >> /home/pi/DSPi/jackboot.log &
  sleep 25
  a2jmidid &
  echo "nernerner"
  sudo ifdown wlan0 &
  exit 0;
)
[ $dspi == 'amsynth' ] && (
  jackd -s -S -P80 -p16 -t2000 -dalsa -dhw:pisound -r48000 -p128 -n3 -s -P -Xnone >> /home/pi/DSPi/jackboot.log &
  # chrt -a -r -p 80 $! &
  sleep 15
  amsynth -x -malsa -ajack -c9 -p4 -r48000 >> /home/pi/DSPi/jackboot.log &
  chrt -a -r -p 75 $! &
  echo "wubwubwub"
  sudo ifdown wlan0 &
  exit 0;
)
[ $dspi == 'debug' ] && (
  sudo ifup wlan0 &
  echo "Debugging" >> /home/pi/DSPi/jackboot.log
  exit 0;
)
exit 1;
