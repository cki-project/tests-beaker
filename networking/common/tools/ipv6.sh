#
# Get a length 128 ipv6 address.
# e.g. you give me 2001:1::44:55:66, i will give you 2001:0001:0000:0000:0000:0044:0055:0066
# 
ipv6_addr_length128()
{
	addr6=$1

	# get 2 substring separated by "::"
	sub1=$(echo $addr6|awk -F"::" '{print $1}')
	sub2=$(echo $addr6|awk -F"::" '{print $2}')
	
	# there are how many section separated by ":" ?
	sub1_section_count=$(($(echo $sub1|grep -o :|wc -l)+1))
	sub2_section_count=$(($(echo $sub2|grep -o :|wc -l)+1))
	if [ -z "$sub1" ];then
		sub1_section_count=0
	fi
	if [ -z "$sub2" ];then
		sub2_section_count=0
	fi
	
	# "::" representing how many "0000" ? caculate this.
	total_section_count=$((sub1_section_count+sub2_section_count))
	zero_section_count=$((8-total_section_count))
	
	# construct full_addr6(use "0000" instead of "::")
	full_addr6=$sub1
	for i in `seq $zero_section_count`;
	do
		# if $sub1 is null, don't insert ":" before "0000", else insert ":"
		if [ -z "$full_addr6" ];then
			full_addr6=0000
		else
			full_addr6=${full_addr6}:0000
		fi
	done
	if [ $sub2_section_count -gt 0 ];then
		full_addr6=${full_addr6}:${sub2}
	fi
	
	# add prefix 0 if section length less then 4
	final_addr6=""
	for i in `seq 1 8`;
	do
		section=${full_addr6%%:*}
		sec_len=${#section}
	        zero_num=$((4-sec_len))
		zero="0000"
		zero=${zero:0:zero_num}
		section=${zero}${section}
		if [ -z "$final_addr6" ];then
			final_addr6=$section
		else
			final_addr6=${final_addr6}:${section}
		fi
		full_addr6=${full_addr6#*:}
	done
	
	echo $final_addr6
}
