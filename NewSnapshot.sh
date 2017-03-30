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
# Gr33nDrag0n / v1.0 / 2017-03-29
# Inspired by Tharude (Ark.io) excellent ark_snapshot.sh script.
#
# Note: I'm using Nginx instead of NodeJS Ark-Explorer to share the files.
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

ArkNetwork="mainnet"
ArkNodeDirectory="$HOME/ark-node"
SnapshotDirectory='/opt/nginx/snapshot.arknode.net'

### Test Ark-Node Started
ArkNodePid=$( pgrep -a "node" | grep ark-node | awk '{print $1}' )
if [ "$ArkNodePid" != "" ] ; then

    ### Delete Snapshot(s) older then 6 hours
    find $SnapshotDirectory -name "ark_$ArkNetwork_*" -type f -mmin +360 -delete

    ### Write SeedNodeFile
    ArkNodeConfig="$ArkNodeDirectory/config.$ArkNetwork.json"
    SeedNodeFile='/tmp/ark_seednode'
    echo '' > $SeedNodeFile
    cat $ArkNodeConfig | jq -c -r '.peers.list[]' | while read Line; do
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

    ### Get local ark-node height
    LocalHeight=$( curl --max-time 2 -s 'http://127.0.0.1:4001/api/loader/status/sync' | jq '.height' )

    ### Test Ark-Node Sync.
    if [ "$LocalHeight" -eq "$TopHeight" ]; then

        ForeverPid=$( forever --plain list | grep $ArkNodePid | sed -nr 's/.*\[(.*)\].*/\1/p' )
        cd $ArkNodeDirectory

        ### Stop Ark-Node
        forever --plain stop $ForeverPid > /dev/null 2>&1 &
        sleep 1

        ### Dump Database
        SnapshotFilename='ark_'$ArkNetwork'_'$LocalHeight
        pg_dump -O "ark_$ArkNetwork" -Fc -Z6 > "$SnapshotDirectory/$SnapshotFilename"
        sleep 1

        ### Start Ark-Node
        forever --plain start app.js --genesis "genesisBlock.$ArkNetwork.json" --config "config.$ArkNetwork.json" > /dev/null 2>&1 &

        ### Update Symbolic Link
        rm -f "$SnapshotDirectory/current"
        ln -s "$SnapshotDirectory/$SnapshotFilename" "$SnapshotDirectory/current"
    fi
fi
