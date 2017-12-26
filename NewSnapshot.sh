#!/bin/bash

###############################################################################
#
#                   `//                     $,  $,     ,"                   
#                  `+oo+`                   `"ss.$ss. .s'"                  
#                 -oooooo-                  .ss$$$$$$$$$$s,"                
#                :oooooooo:                 $$$$$$$$$$$$$`$$Ss"             
#              `+oooo:/oooo/`               $$$$$$$$$$$$$$o$$$       ,"     
#             .+ooo:`  `/ooo+.              $$$$$$$$$$$$$$$$$$$$$s,  ,s"    
#            :ooo:` -+/- `/ooo-             $$$$$"$$$$$$""""$$$$$$"$$$$$,'  
#           /oo:`  `....`  `/oo:            $$$$$$s""$$$$ssssss"$$$$$$$$"'  
#         `+o/` -+++++/+++/. `/o+`          $$$$$'         `"""ss"$"$s""'   
#        .o/`  -------------.  `/+.         $$$$$,              `"""""$'    
#       :/.                      `/:        $$$$$$$s,..."                   
#      -.                          `-       $$$$$$$$$$$$$$$$$$$$$$s.        
#
#
# gsilvestri / v1.0 / 2017-12-26
# Inspired by Tharude (Ark.io) excellent ark_snapshot.sh script.
#
# Note: I'm using Nginx instead of NodeJS Kapu-Explorer to share the files.
#
# - Save to /home/##USER##/NewSnapshot.sh
#
# - chmod 700 /home/##USER##/NewSnapshot.sh
#
# - Edit FinalDirectory variable
#   Make sure it's writable by snapshot user and readable by nginx user.
#
# - Edit Crontab
#      crontab -u ##USER## -e
#      2,17,32,47 * * * * /home/##USER##/NewSnapshot.sh > /dev/null 2>&1 &
#
###############################################################################

KapuNetwork="mainnet"
KapuNodeDirectory="$HOME/kapu-node"
SnapshotDirectory='/opt/nginx/snapshot.kapunode.net'

### Test kapu-node Started
KapuNodePid=$( pgrep -a "node" | grep kapu-node | awk '{print $1}' )
if [ "$KapuNodePid" != "" ] ; then

    ### Delete Snapshot(s) older then 6 hours
    find $SnapshotDirectory -name "kapu_$KapuNetwork_*" -type f -mmin +360 -delete

    ### Write SeedNodeFile
    KapuNodeConfig="$KapuNodeDirectory/config.$KapuNetwork.json"
    SeedNodeFile='/tmp/kapu_seednode'
    echo '' > $SeedNodeFile
    cat $KapuNodeConfig | jq -c -r '.peers.list[]' | while read Line; do
        SeedNodeAddress="$( echo $Line | jq -r '.ip' ):$( echo $Line | jq -r '.port' )"
        echo "$SeedNodeAddress" >>  "$SeedNodeFile"
    done

    ### Load SeedNodeFile in Memory & Remove SeedNodeFile
    declare -a SeedNodeList=()
    while read Line; do
        SeedNodeList+=($Line)
    done < $SeedNodeFile
    rm -f $SeedNodeFile

    ### Get highest Height from 8 random seed nodes
    SeedNodeCount=${#SeedNodeList[@]}
    for (( TopHeight=0, i=1; i<=8; i++ )); do
        RandomOffset=$(( RANDOM % $SeedNodeCount ))
        SeedNodeUri="http://${SeedNodeList[$RandomOffset]}/api/loader/status/sync"
        SeedNodeHeight=$( curl --max-time 2 -s $SeedNodeUri | jq -r '.height' )
        if [ "$SeedNodeHeight" -gt "$TopHeight" ]; then TopHeight=$SeedNodeHeight; fi
    done

    ### Get local kapu-node height
    LocalHeight=$( curl --max-time 2 -s 'http://127.0.0.1:4600/api/loader/status/sync' | jq '.height' )

    ### Test kapu-node Sync.
    if [ "$LocalHeight" -eq "$TopHeight" ]; then

        ForeverPid=$( forever --plain list | grep $KapuNodePid | sed -nr 's/.*\[(.*)\].*/\1/p' )
        cd $KapuNodeDirectory

        ### Stop kapu-node
        forever --plain stop $ForeverPid > /dev/null 2>&1 &
        sleep 1

        ### Dump Database
        SnapshotFilename='kapu_'$KapuNetwork'_'$LocalHeight
        pg_dump -O "kapu_$KapuNetwork" -Fc -Z6 > "$SnapshotDirectory/$SnapshotFilename"
        sleep 1

        ### Start kapu-node
        forever --plain start app.js --genesis "genesisBlock.$KapuNetwork.json" --config "config.$KapuNetwork.json" > /dev/null 2>&1 &

        ### Update Symbolic Link
        rm -f "$SnapshotDirectory/current"
        ln -s "$SnapshotDirectory/$SnapshotFilename" "$SnapshotDirectory/current"
    fi
fi
