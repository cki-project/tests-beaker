### Gloable parameter setting for ipsec
IPSEC_PARA_LOG="/tmp/ipsec-setting.log"

while getopts "hm:p:s:S:k:a:t:e:A:c:6" opt; do
	case "$opt" in
	h)
		echo "Usage:"
		echo "h        help"
		echo "m x      x is ipsec mode, could be transport / tunnel / beet"
		echo "p x      x is ipsec protocol, could be ah / esp / ipcomp"
		echo "s x      x is icmp messge size array"
		echo "S n      n is IPsec SPI value"
		echo "k x      key for vti interface"
		echo "a x      Authenticated algorithm(auth):"
		echo "             sha1,sha256,sha384,sha512,rmd160"
		echo "t x      Authenticated algorithm(auth-trunc):"
		echo "             sha1,sha256,sha384,sha512,rmd160"
		echo "e x      Encryption algorithm:"
		echo "             des,des3_ede,cast5,blowfish,aes,twofish,camellia,serpent"
		echo "A x      Authentication encryption with associated data algorithm(AEAD):"
		echo "             rfc4106_128,rfc4106_192,rfc4106_256"
		echo "             rfc4309_128,rfc4309_192,rfc4309_256"
		echo "             rfc4543_128,rfc4543_192,rfc4543_256"
		echo "c x      Compression algorithm"
		echo "6        run over IPv6"
		exit 0
	;;
	m)	IPSEC_MODE=$OPTARG ;;
	p)	IPSEC_PROTO=$OPTARG ;;
	s)	IPSEC_SIZE_ARRAY="$OPTARG" ;;
	S)	SPI=$OPTARG ;;
	k)	VTI_KEY=$OPTARG ;;
	a)	AALGO=$OPTARG ;;
	t)	ATALGO=$OPTARG ;;
	e)	EALGO=$OPTARG ;;
	A)	AEALGO=$OPTARG ;;
	c)	CALGO=$OPTARG ;;
	6)	TEST_VER=6 ;;
	*)	echo "Error: unknown option: $opt" | tee $IPSEC_PARA_LOG; report_result $TEST WARN; rhts-abort -t recipe ;;
	esac
done

# Authenticated encryption with associated data
AEALGO=${AEALGO:-"rfc4106_128"}
# Encryption algorithm
EALGO=${EALGO:-""}
# Authentication algorithm(auth)
AALGO=${AALGO:-""}
# Authentication algorithm(auth-trunc)
ATALGO=${ATALGO:-""}
# Compression algorithm
CALGO=${CALGO:-"deflate"}

IPSEC_PROTO=${IPSEC_PROTO:-"esp_aead"}
IPSEC_MODE=${IPSEC_MODE:-"transport"}
SPI=${SPI:-1000}
VTI_KEY=${VTI_KEY:-10}
IPSEC_SIZE_ARRAY="${IPSEC_SIZE_ARRAY:-10 1000 10000 65000}"
TEST_VER=${TEST_VER:-4}

get_key()
{
	local bits=$1
	local bytes=$(( $bits / 8 ))
	key=$(echo $(for i in $(seq $bytes); do echo -n '0f'; done))
	echo 0x$key
}

case $AEALGO in
rfc4106_128|rfc4543_128) AEALGO_KEY=$(get_key 160) ;;
rfc4106_192|rfc4543_192) AEALGO_KEY=$(get_key 224) ;;
rfc4106_256|rfc4543_256) AEALGO_KEY=$(get_key 288) ;;
rfc4309_128) AEALGO_KEY=$(get_key 152) ;;
rfc4309_192) AEALGO_KEY=$(get_key 216) ;;
rfc4309_256) AEALGO_KEY=$(get_key 280) ;;
esac

case $EALGO in
des) EALGO_KEY=$(get_key 64) ;;
des3_ede) EALGO_KEY=$(get_key 192) ;;
cast5) EALGO_KEY=$(get_key 128) ;;
blowfish) EALGO_KEY=$(get_key 448) ;;
aes|twofish|camellia|serpent) EALGO_KEY=$(get_key 256) ;;
esac

case $AALGO in
sha1|rmd160) AALGO_KEY=$(get_key 160) ;;
sha256) AALGO_KEY=$(get_key 256) ;;
sha384) AALGO_KEY=$(get_key 384) ;;
sha512) AALGO_KEY=$(get_key 512) ;;
esac

case $ATALGO in
sha1|rmd160) ATALGO_KEY=$(get_key 160) ;;
sha256) ATALGO_KEY=$(get_key 256) ;;
sha384) ATALGO_KEY=$(get_key 384) ;;
sha512) ATALGO_KEY=$(get_key 512) ;;
esac

# PROTO and ALG setting
PROTO="proto $IPSEC_PROTO"
[ "$IPSEC_PROTO" = "esp_aead" ] && PROTO="proto esp"

case $IPSEC_PROTO in
ah)
	if [ ! -z $AALGO ];then
		ALG='auth hmac\('$AALGO'\) '$AALGO_KEY
	elif [ ! -z $ATALGO ];then
		ALG='auth-trunc hmac\('$ATALGO'\) '$ATALGO_KEY" 96"
	else
		echo "Error: ah protocol doesn't set authentication" | tee $IPSEC_PARA_LOG
                report_result $TEST WARN
                rhts-abort -t recipe
	fi
	;;
esp)
	if [ ! -z $AALGO ];then
		ALG='auth hmac\('$AALGO'\) '$AALGO_KEY
	elif [ ! -z $ATALGO ];then
		ALG='auth-trunc hmac\('$ATALGO'\) '$ATALGO_KEY" 96"
	fi
	if [ ! -z $EALGO ];then
		ALG="enc $EALGO $EALGO_KEY "$ALG
	else
		echo "Error: esp protocol doesn't set encryption" | tee $IPSEC_PARA_LOG
                report_result $TEST WARN
                rhts-abort -t recipe
	fi
	;;
esp_aead)
	case $AEALGO in
	rfc4106_128|rfc4106_192|rfc4106_256)
		ALG="aead "'rfc4106\(gcm\(aes\)\)'" $AEALGO_KEY 128"
		;;
	rfc4309_128|rfc4309_192|rfc4309_256)
		ALG="aead "'rfc4309\(ccm\(aes\)\)'" $AEALGO_KEY 128"
		;;
	rfc4543_128|rfc4543_192|rfc4543_256)
		ALG="aead "'rfc4543\(gcm\(aes\)\)'" $AEALGO_KEY 128"
		;;
	esac
	;;
comp)
	uname -r |grep el6 && ALG="comp $CALGO 0x" || ALG="comp $CALGO"
	;;
*)
	echo "Error: tst_ipsec protocol mismatch" | tee $IPSEC_PARA_LOG
                report_result $TEST WARN
                rhts-abort -t recipe
	;;
esac

echo "TEST_VER=$TEST_VER, SPI=$SPI, IPSEC_MODE=$IPSEC_MODE, PROTO=$PROTO, ALG=$ALG"

# modules related ipsec test
MOD_DIR="/lib/modules/$(uname -r)"
ALLMODULES="
$(ls ${MOD_DIR}/kernel/arch/x86/crypto/ | sed 's/-/_/g')
$(ls ${MOD_DIR}/kernel/crypto/*|grep ko| awk -F/ '{print $NF}'| awk -F. '{print $1}'| sed 's/-/_/g')
$(ls ${MOD_DIR}/kernel/net/* |grep ko| awk -F/ '{print $NF}'| awk -F. '{print $1}'| sed 's/-/_/g')
"
remove_modules(){
	local i
	local module
	for i in `seq 5`;do
		for module in `lsmod |awk '/ 0 / {print $1}'`; do
			if echo "$ALLMODULES"|grep $module > /dev/null;then
				rlRun "rmmod $module"
			fi
		done
	done
}
