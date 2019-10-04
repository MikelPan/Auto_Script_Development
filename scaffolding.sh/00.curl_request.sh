#/bin/bash
#Author:Mikel
#Time:2019-09-29 23:24:04
#Name:00.curl_request.sh
#Version:V1.0
#Description:This is a shell scripts for check request

# get request

# define var
StgCentUrl='https://cent.kptest.cn'
StgDistSzUrl='https://dist-sz.kptest.cn'
PreCenUrl='https://cent-pre.kpmember.cn'
PreDistSzUrl='https://dist-pre-sz.kpmember.cn'

# request to stg cent
Url(){
    source ~/.bashrc
    ServiceName=$1
    Host=`kcs -A | grep $ServiceName | awk '{print $3}'`
    Api=$2
    Url=http://$Host/$Api
}
RequestUrl $1 $2
Url=$?

Request(){
    curl -v -s $Url
    if http_code 
}


