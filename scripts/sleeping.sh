#!/bin/bash
#
count=10000
if [ ${ISO_PATH_SUCESS} === 0 ];then
    while ! [ $count == 0 ]
    do
        echo "Wait: $count Seconds"
        echo "Ngrok Url: $(curl -s localhost:4040/api/tunnels | jq -r .tunnels[0].public_url)"
        echo "Ngrok Url: $(curl -s localhost:4040/api/tunnels | jq -r .tunnels[1].public_url)"
        echo "-*-*-*-*-*-*-*-"
        sleep 10s
        count=$(( $count - 1 ))
        [ $count == '-1' ] && break
    done
fi
exit 0