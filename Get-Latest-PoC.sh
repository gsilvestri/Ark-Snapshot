#------------------------------------------------------------------------------
# Author:        Gr33nDrag0n
# Last Update:   2017-03-26
#
# PoC Get Latest in BASH (For integration in ArkCommander.sh)
#------------------------------------------------------------------------------

#SrcFilenameFilter="ark_mainnet_[0-9]"
# Debug only since Ark.io still with testnet snapshots.
SrcFilenameFilter="ark_*_[0-9]"

declare -A RemoteFile
RemoteFile['FullPath']=''
RemoteFile['FileName']=''
RemoteFile['Height']=0

read -e -r -p "Download from Ark.io? (1) ArkNode.net? (2) Seatrips.eu (3) or use Local (L)" -i "1" CHOICE
if [[ "$CHOICE" =~ [1]$ ]]; then
	echo -e "Downloading latest snapshot from Ark.io\n"
	SrcRepo='https://explorer.ark.io/snapshots/'
	RemoteFile['FileName']=$( curl -s $SrcRepo | grep -o "$SrcFilenameFilter" | sort | tail -n 1 )
	RemoteFile['FullPath']=$( curl -s $SrcRepo | grep -o "$SrcFilenameFilter" | sort | tail -n 1 )
	RemoteFile['Height']=$( echo ${RemoteFile['FileName']} | grep -oh "[0-9]*" )
	
	echo "FileName => ${RemoteFile['FileName']}"
	echo "FullPath => ${RemoteFile['FullPath']}"
	echo "Height => ${RemoteFile['Height']}"
	
#	wget -nv ${RemoteFile['FullPath']} -O $SNAPDIR/current
elif [[ "$CHOICE" =~ [2]$ ]]; then
	echo -e "Downloading latest snapshot from ArkNode.net\n"
	SrcRepo='https://snapshot.arknode.net/'
	RemoteFile['FileName']=$( curl -s $SrcRepo | grep -o "$SrcFilenameFilter" | sort | tail -n 1 )
	RemoteFile['FullPath']=$( curl -s $SrcRepo | grep -o "$SrcFilenameFilter" | sort | tail -n 1 )
	RemoteFile['Height']=$( echo ${RemoteFile['FileName']} | grep -oh "[0-9]*" )
	
	echo "FileName => ${RemoteFile['FileName']}"
	echo "FullPath => ${RemoteFile['FullPath']}"
	echo "Height => ${RemoteFile['Height']}"
	
#	wget -nv ${RemoteFile['FullPath']} -O $SNAPDIR/current
elif [[ "$CHOICE" =~ [3]$ ]]; then
	echo -e "Downloading latest snapshot from Seatrips.eu\n"
	SrcRepo='https://arkexplorer.seatrips.eu/snapshots/'
	RemoteFile['FileName']=$( curl -s $SrcRepo | grep -o "$SrcFilenameFilter" | sort | tail -n 1 )
	RemoteFile['FullPath']=$( curl -s $SrcRepo | grep -o "$SrcFilenameFilter" | sort | tail -n 1 )
	RemoteFile['Height']=$( echo ${RemoteFile['FileName']} | grep -oh "[0-9]*" )
	
	echo "FileName => ${RemoteFile['FileName']}"
	echo "FullPath => ${RemoteFile['FullPath']}"
	echo "Height => ${RemoteFile['Height']}"
	
#	wget -nv ${RemoteFile['FullPath']} -O $SNAPDIR/current
fi

