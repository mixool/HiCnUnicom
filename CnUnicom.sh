#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin && export PATH
# Usage:
## wget --no-check-certificate https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh && chmod +x CnUnicom.sh && bash CnUnicom.sh membercenter 13800008888@112233 18388880000@123456
### bash <(curl -m 10 -s https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh) membercenter 13800008888@112233 18388880000@123456

# 传入参数格式，支持多账号，手机号@密码必需：13800008888@112233 18388880000@123456
[[ $# != 0 ]] && all_parameter=($(echo $@)) || { echo 'Err  !!! Useage: bash this_script.sh membercenter 13800008888@112233 18388880000@123456'; exit 1; }
all_username_password=($(echo ${all_parameter[*]} | grep -oE "[0-9]{11}@[0-9]{6}"| sort -u | tr "\n" " "))

# 登录失败尝试修改以下这个appId的值为抓包获取的登录过的联通app,也可使用传入参数 appId@*************
appId=247b001385de5cc6ce11731ba1b15835313d489d604e58280e455a6c91e5058651acfb0f0b77029c2372659c319e02645b54c0acc367e692ab24a546b83c302d
echo ${all_parameter[*]} | grep -qE "appId@[a-z0-9]+" && appId=$(echo ${all_parameter[*]} | grep -oE "appId@[a-z0-9]+" | cut -f2 -d@)

# deviceId: 随机IMEI,也可使用传入参数 deviceId@*************
deviceId=$(shuf -i 123456789012345-987654321012345 -n 1)
echo ${all_parameter[*]} | grep -qE "deviceId@[0-9]+" && deviceId=$(echo ${all_parameter[*]} | grep -oE "deviceId@[0-9]+" | cut -f2 -d@)

# 使用Github Action运行时需要传入参数来修改工作路径: githubaction
workdirbase="/tmp/log/CnUnicom"
echo ${all_parameter[*]} | grep -qE "githubaction" && workdirbase="$(pwd)/CnUnicom"

# 联通APP版本
unicom_version=8.0200

#####
## 流量激活功能需要传入参数,中间d表示每天,w表示每周一,m代表每月第二天,格式： liulactive@d@ff80808166c5ee6701676ce21fd14716
## 如仅需要部分号码激活流量包时使用参数格式：liulactive@d@ff80808166c5ee6701676ce21fd14716@13012341234-18812341234
## 1GB日包：          ff80808166c5ee6701676ce21fd14716
## 2GB日包:           21010621565413402
## 5GB日包:           21010621461012371
## 10GB日包:          21010621253114290
## 4GB流量七日包:     20080615550312483
## 100MB全国流量月包: ff80808165afd2960165d1eb75424667
## 300MB全国流量月包：ff80808165afd2960165d1e93423464a
## 500MB全国流量月包: ff80808165afd2960165cdbf4a950c1c
## 1GB全国流量月包：  ff80808165afd2960165cdbc92470bef
#####

################################################################
function rsaencrypt() {
    cat > $workdir/rsa_public.key <<-EOF
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDc+CZK9bBA9IU+gZUOc6
FUGu7yO9WpTNB0PzmgFBh96Mg1WrovD1oqZ+eIF4LjvxKXGOdI79JRdve9
NPhQo07+uqGQgE4imwNnRx7PFtCRryiIEcUoavuNtuRVoBAm6qdB0Srctg
aqGfLgKvZHOnwTjyNqjBUxzMeQlEC2czEMSwIDAQAB
-----END PUBLIC KEY-----
EOF

    crypt_username=$(echo -n $username | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
    crypt_password=$(echo -n $password | openssl rsautl -encrypt -inkey $workdir/rsa_public.key -pubin -out >(base64 | tr "\n" " " | sed s/[[:space:]]//g))
}

function urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
        esac
    done
}

function userlogin() {
    rsaencrypt
    cat > $workdir/signdata <<-EOF
isRemberPwd=true
&deviceId=$deviceId
&password=$(urlencode $crypt_password)
&simCount=0
&netWay=Wifi
&mobile=$(urlencode $crypt_username)
&yw_code=
&timestamp=$(date +%Y%m%d%H%M%S)
&appId=$appId
&keyVersion=1
&deviceBrand=Xiaomi
&pip=10.0.$(shuf -i 1-255 -n 1).$(shuf -i 1-255 -n 1)
&provinceChanel=general
&version=android%40$unicom_version
&deviceModel=MI%209
&deviceOS=android11
&deviceCode=$deviceId
EOF

    # cookie登录
    [[ ! -f $workdir/token_online ]] && touch $workdir/token_online
    data="deviceId=$deviceId&netWay=Wifi&reqtime=$(date +%s)$(shuf -i 100-999 -n 1)&flushkey=1&version=android%40${unicom_version}&deviceModel=MI%209&token_online=$(cat $workdir/token_online | grep -oE "token_online\":\"[^\"]*" | cut -f3 -d\")&appId=$appId&deviceBrand=Xiaomi&deviceCode=$deviceId"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie -c $workdir/cookie --data "$data" https://m.client.10010.com/mobileService/onLine.htm >$workdir/token_online
    cat $workdir/token_online | grep -qE "token_online" && status=0 || status=1
    [[ $status == 0 ]] && echo && echo $(date) cookies登录${username:0:2}******${username:9}成功
    
    # 账号密码登录
    if [[ $status == 1 ]]; then
        rm -rf $workdir/cookie*
        curl -m 10 -X POST -sA "$UA" -c $workdir/cookie "https://m.client.10010.com/mobileService/logout.htm?&desmobile=$username&version=android%40$unicom_version" >/dev/null
        curl -m 10 -sA "$UA" -b $workdir/cookie -c $workdir/cookie -d @$workdir/signdata "https://m.client.10010.com/mobileService/login.htm" >$workdir/token_online
        token=$(cat $workdir/cookie | grep -E "a_token" | awk  '{print $7}')
        [[ "$token" = "" ]] && echo && echo $(date) ${username:0:2}******${username:9} Login Failed. && rm -rf $workdir && return 1
        echo && echo $(date) 密码登录${username:0:2}******${username:9}成功
    fi
}

function membercenter() {
    echo ${all_parameter[*]} | grep -qE "membercenter" || return 0
    echo && echo starting membercenter...
    
    # 获取文章和评论生成数组数据
    NewsListId=($(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pageNum=1&pageSize=10&reqChannel=00" https://m.client.10010.com/commentSystem/getNewsList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    comtId=($(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    nickId=($(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "nickName\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    Referer="https://img.client.10010.com/kuaibao/detail.html?pageFrom=${NewsListId[0]}"
   
    # 评论点赞后取消点赞
    for ((i = 0; i <= 5; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=01&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise >$workdir/csPraise.log
        cat $workdir/csPraise.log | grep -oE "growScore\":\"[0-9]+"; cat $workdir/csPraise.log | grep -qE "growScore\":\"0\"" && break
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=02&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise >/dev/null
    done
    
    # 文章点赞后取消点赞
    for ((i = 0; i <= 5; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=01&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise >$workdir/csPraise.log
        cat $workdir/csPraise.log | grep -oE "growScore\":\"[0-9]+"; cat $workdir/csPraise.log | grep -qE "growScore\":\"0\"" && break
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=02&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise >/dev/null
    done
    
    # 文章评论后删除评论
    newsTitle="$(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "mainTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    subTitle="$(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "subTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    for ((i = 0; i <= 5; i++)); do
        data="id=${NewsListId[1]}&newsTitle=$(urlencode $newsTitle)&commentContent=$RANDOM&upLoadImgName=&reqChannel=quickNews&subTitle=$(urlencode $subTitle)&belongPro=098"
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "$data" -e "$Referer" https://m.client.10010.com/commentSystem/saveComment >$workdir/csPraise.log
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "type=01&reqId=$(cat $workdir/csPraise.log | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}')&reqChannel=quickNews" -e "$Referer" https://m.client.10010.com/commentSystem/delDynamic >/dev/null
        cat $workdir/csPraise.log | grep -oE "growScore\":\"[0-9]+"; cat $workdir/csPraise.log | grep -qE "growScore\":\"0\"" && break
    done
    
    # 每月一次账单查询
    if [[ "$(date "+%d")" == "05" ]]; then
        echo && echo
        curl -m 10 -sLA "$UA" -b $workdir/cookie --data "yw_code=&desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryHistoryBill.htm?mobile_c_from=home" >/dev/null
        curl -m 10 -sLA "$UA" -b $workdir/cookie --data "systemCode=CLIENT&transId=&userNumber=$username&taskCode=TA52554375&finishTime=$(date +%Y%m%d%H%M%S)" "https://act.10010.com/signinAppH/limitTask/limitTime" >/dev/null
    fi

    # 每日一次余量查询
    echo && echo
    curl -m 10 -sLA "$UA" -b $workdir/cookie --data "desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryLeavePackage.htm" >/dev/null
    curl -m 10 -sLA "$UA" -b $workdir/cookie --data "type=0" "https://m.client.10010.com/mobileService/grow/marginCheck.htm"
    
    # 签到
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/daySign?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)"
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/todaySign" | grep -oE "status\":\"[0-9]+"

    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/getContinuous"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/getIntegral"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/getGoldTotal"
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/signin/bannerAdPlayingLogo"
    ## 每日领取1G流量日包
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/doTask/finishVideo"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/doTask/getTaskInfo"
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie "https://act.10010.com/SigninApp/doTask/getPrize"

    # 三次金币抽奖， 每日最多可花费金币执行十三次
    echo && echo
    usernumberofjsp=$(curl -m 10 -sA "$UA" -b $workdir/cookie https://m.client.10010.com/dailylottery/static/textdl/userLogin | grep -oE "encryptmobile=\w*" | awk -F"encryptmobile=" '{print $2}'| head -n1)
    for ((i = 1; i <= 3; i++)); do
        [[ $i -gt 3 ]] && curl -m 10 -sA "$UA" -b $workdir/cookie --data "goldnumber=10&banrate=10&usernumberofjsp=$usernumberofjsp" https://m.client.10010.com/dailylottery/static/doubleball/duihuan >/dev/null; sleep 1
        curl -m 10 -sA "$UA" -b $workdir/cookie --data "usernumberofjsp=$usernumberofjsp&flag=convert" https://m.client.10010.com/dailylottery/static/doubleball/choujiang | grep -oE "用户机会次数不足" && break
    done
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie -e "$Referer" "https://act.10010.com/SigninApp/signin/getGoldTotal?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)" | grep -oE "goldTotal\":\"[0-9]+"
    
    # 积分抽奖首次免费，之后领300定向积分兑换再抽奖,最多三十次
    echo && echo
    curl -m 10 -X POST -sLA "$UA" -b $workdir/cookie --data "from=$(shuf -i 12345678901-98765432101 -n 1)" "https://m.client.10010.com/welfare-mall-front/mobile/winterTwo/getIntegral/v1"
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang
    for ((i = 1; i <= 3; i++)); do
        curl -m 10 -sA "$UA" -b $workdir/cookie --data "goldnumber=10&banrate=30&usernumberofjsp=$usernumberofjsp" http://m.client.10010.com/dailylottery/static/integral/duihuan >/dev/null; sleep 1
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang | grep -oE "用户机会次数不足" && break
    done
    
    # 每日领100定向积分
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "from=$(shuf -i 12345678901-98765432101 -n 1)" https://m.client.10010.com/welfare-mall-front/mobile/integral/gettheintegral/v1
    
    # 游戏签到积分 每日1积分
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=iOSIntegralGet&gameLevel=1&deviceType=iOS" "https://m.client.10010.com/producGameApp"
    
    # 奖励积分
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=signin" https://m.client.10010.com/producGame_signin
    
    # 游戏宝箱
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=N" https://m.client.10010.com/game_box
    echo && echo
    curl -m 10 -sA "$UA" -b $workdir/cookie --data "methodType=taskGetReward&taskCenterId=187&clientVersion=$unicom_version&deviceType=Android" https://m.client.10010.com/producGameTaskCenter
    echo && echo
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=Y" https://m.client.10010.com/game_box
    
    # 沃之树浇水，免费一次，服务器经常502错误，所以请求三次
    echo && echo
    for ((i = 1; i <= 3; i++)); do sleep 3 && curl -m 10 -X POST -sA "$UA" -b $workdir/cookie -e "https://img.client.10010.com/mactivity/woTree/index.html" https://m.client.10010.com/mactivity/arbordayJson/arbor/3/0/3/grow.htm | grep -oE "addedValue\":[0-9]" && break; done
    
    # 获得流量
    echo && echo
    for ((i = 1; i <= 3; i++)); do
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=22" https://act.10010.com/SigninApp/mySignin/addFlow >/dev/null; sleep 3
        curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=23" https://act.10010.com/SigninApp/mySignin/addFlow | grep -oE "reason\":\"01" && break
    done
}

function liulactive() {
    # 流量激活功能
    echo ${all_parameter[*]} | grep -qE "liulactive@[mwd]@[0-9a-z]+" || return 0
    timeparId=$(echo ${all_parameter[*]} | grep -oE "liulactive@[mwd]@[0-9a-z]+" | cut -f2 -d@)
    productId=$(echo ${all_parameter[*]} | grep -oE "liulactive@[mwd]@[0-9a-z]+" | cut -f3 -d@)
    choosenos=$(echo ${all_parameter[*]} | grep -oE "liulactive@[mwd]@[0-9a-z]+@.*" | cut -f4 -d@)
    # 依照参数m|w|d来判断是否执行
    unset liulactive_run
    [[ ${timeparId} == "m" ]] && [[ "$(date +%d)" == "02" ]] && liulactive_run=true
    [[ ${timeparId} == "w" ]] && [[ "$(date +%u)" == "1" ]]  && liulactive_run=true
    [[ ${timeparId} == "d" ]] && liulactive_run=true
    [[ "$liulactive_run" == "true" ]] || return 0
    # 依照参数choosenos来判断是否是指定号码执行,激活功能的参数全格式： liulactive@d@ff80808166c5ee6701676ce21fd14716@13012341234-13112341234
    unset liulactive_only
    [[ $choosenos != "" ]] && echo $choosenos | grep -qE "${username}" && liulactive_only=true
    [[ $choosenos == "" ]] && liulactive_only=true
    [[ "$liulactive_only" == "true" ]] || return 0
    # 激活请求
    echo && echo starting liulactive...
    curl -m 10 -sA "$UA" -b $workdir/cookie -c $workdir/cookie_liulactive "https://m.client.10010.com/MyAccount/trafficController/myAccount.htm?flag=1&curl -m 10=https://m.client.10010.com/myPrizeForActivity/querywinninglist.htm?pageSign=1" >$workdir/liulactive.log
    liulactiveuserLogin="$(cat $workdir/liulactive.log | grep "refreshAccountTime" | grep -oE "[0-9_]+")"
    curl -m 10 -sA "$UA" -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive "https://m.client.10010.com/MyAccount/MyGiftBagController/refreshAccountTime.htm?userLogin=$liulactiveuserLogin&accountType=FLOW" >/dev/null
    curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive --data "thirdUrl=thirdUrl=https%3A%2F%2Fm.client.10010.com%2FMyAccount%2FtrafficController%2FmyAccount.htm" https://m.client.10010.com/mobileService/customer/getShareRedisInfo.htm >/dev/null
    Referer="https://m.client.10010.com/MyAccount/trafficController/myAccount.htm?flag=1&curl -m 10=https://m.client.10010.com/myPrizeForActivity/querywinninglist.htm?pageSign=1"
    curl -m 10 -X POST -sA "$UA" -e "$Referer" -b $workdir/cookie_liulactive -c $workdir/cookie_liulactive --data "productId=$productId&userLogin=$liulactiveuserLogin&ebCount=1000000&pageFrom=4" "https://m.client.10010.com/MyAccount/exchangeDFlow/exchange.htm?userLogin=$liulactiveuserLogin" | grep -B 1 "正在为您激活"
}

function libaollactive() {
    # 我的礼包流量激活功能
    echo ${all_parameter[*]} | grep -qE "libaollactive@[mwd]" || return 0
    timeparId=$(echo ${all_parameter[*]} | grep -oE "libaollactive@[mwd]" | cut -f2 -d@)
    choosenos=$(echo ${all_parameter[*]} | grep -oE "libaollactive@[mwd]@.*" | cut -f3 -d@)
    # 依照参数m|w|d来判断是否执行
    unset liulactive_run
    [[ ${timeparId} == "m" ]] && [[ "$(date +%d)" == "01" ]] && libaollactive_run=true
    [[ ${timeparId} == "w" ]] && [[ "$(date +%u)" == "1" ]]  && libaollactive_run=true
    [[ ${timeparId} == "d" ]] && libaollactive_run=true
    [[ "$libaollactive_run" == "true" ]] || return 0
    # 依照参数choosenos来判断是否是指定号码执行,激活功能的参数全格式： libaollactive@d@13012341234-13112341234
    unset libaollactive_only
    [[ $choosenos != "" ]] && echo $choosenos | grep -qE "${username}" && libaollactive_only=true
    [[ $choosenos == "" ]] && libaollactive_only=true
    [[ "$libaollactive_only" == "true" ]] || return 0
    # 激活请求
    echo && echo starting libaollactive...
    curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie --data "typeScreenCondition=2&category=FFLOWPACKET&pageSign=1&CALLBACKURL=https%3A%2F%2Fm.client.10010.com%2FmyPrizeForActivity%2Fquerywinninglist.htm" http://m.client.10010.com/myPrizeForActivity/mygiftbag.htm >$workdir/libaollactive.log
    libaollCode=$(echo $(cat $workdir/libaollactive.log | grep -m 1 'onclick="toDetailPage' | grep -oE "[0-9yh]+") | awk -F ' ' '{print $1}')
    libaollID=$(echo $(cat $workdir/libaollactive.log | grep -m 1 'onclick="toDetailPage' | grep -oE "[0-9yh]+") | awk -F ' ' '{print $2}')    
    libaollName=$(echo $(cat $workdir/libaollactive.log | grep -m 1 '<li>活动') | awk -F '活动：|</li>' '{print $2}' | tr -d '\n' | xxd -plain | sed 's/\(..\)/%\1/g' | tr a-z A-Z)
    curl -m 10 -X POST -sA "$UA"  -b $workdir/cookie --data "activeCode=$libaollCode&prizeRecordID=$libaollID&activeName=$libaollName" http://m.client.10010.com/myPrizeForActivity/myPrize/activationFlowPackages.htm
}

function hfgoactive() {
    # 话费购活动，需传入参数 hfgoactive
    echo ${all_parameter[*]} | grep -qE "hfgoactive" || return 0
    echo && echo starting hfgoactive...
    echo $(echo ${username:0:2}******${username:9}) >$workdir/hfgoactive.info
    curl -m 10 -sLA "$UA" -b $workdir/cookie -c $workdir/cookie_hfgo "https://m.client.10010.com/mobileService/openPlatform/openPlatLineNew.htm?to_url=https://account.bol.wo.cn/cuuser/open/openLogin/hfgo&yw_code=&desmobile=${username}&version=android@${unicom_version}" >/dev/null
    # 每日签到并抽奖,抽奖免费3次,连续签到七天获得额外3次，每日签到有机会获取额外机会
    ACTID="$(curl -m 10 -X POST -sA "$UA" -b $workdir/cookie_hfgo --data "positionType=1" https://hfgo.wo.cn/hfgoapi/product/ad/list | grep -oE "atplottery[^?]*" | cut -f2 -d/)"
    echo $ACTID | grep -vE "[a-zA-Z0-9]+" && echo Unauthorized && return 1
    curl -m 10 -sLA "$UA" -b $workdir/cookie_hfgo -c $workdir/cookie_hfgo "https://hfgo.wo.cn/hfgoapi/cuuser/auth/autoLogin?redirectUrl=https://atp.bol.wo.cn/atplottery/${ACTID}?product=hfgo&ch=002&$(cat $workdir/cookie_hfgo | grep -oE "[^_]token.*" | sed s/[[:space:]]//g | sed "s/token/Authorization=/")" >/dev/null
    # 签到
    curl -m 10 -sA "$UA"  -b $workdir/cookie_hfgo https://atp.bol.wo.cn/atpapi/act/actUserSign/everydaySign?actId=1516 >$workdir/hfgoactivesign.log
    cat $workdir/hfgoactivesign.log
    cat $workdir/hfgoactivesign.log | grep -qE "Unauthorized" && return 1
    # 抽奖
    for ((i = 1; i <= 9; i++)); do
        echo && echo
        curl -m 10 -sA "$UA"  -b $workdir/cookie_hfgo "https://atp.bol.wo.cn/atpapi/act/lottery/start/v1/actPath/${ACTID}/0" >$workdir/lottery_hfgo.log
        cat $workdir/lottery_hfgo.log | grep -oE "抽奖次数已用完" && break
        cat $workdir/lottery_hfgo.log | grep -oE "Unauthorized" && break
        cat $workdir/lottery_hfgo.log | grep -oE "prizeName\":\"[^\"]*" | cut -f3 -d\" >>$workdir/hfgoactive.info
    done
    #
    cat $workdir/hfgoactive.info
}

function jifeninfo() {
    # 积分信息显示，需传入参数 jifeninfo
    echo ${all_parameter[*]} | grep -qE "jifeninfo" || return 0
    echo && echo starting jifeninfo...
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "reqsn=&reqtime=&cliver=&reqdata=" "https://m.client.10010.com/welfare-mall-front/mobile/show/queryUserTotalScore/v1" >$workdir/jifeninfo.log1 
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "reqsn=&reqtime=&cliver=&reqdata=" "https://m.client.10010.com/welfare-mall-front/mobile/show/flDetail/v1/0" >$workdir/jifeninfo.log2
    #
    unset total invalid canUse availablescore invalidscore addScore todayscore yesterdayscore
    total=$(cat $workdir/jifeninfo.log1 | grep -oE "total\":[0-9]+" | grep -oE "[0-9]+")
    invalid=$(cat $workdir/jifeninfo.log1 | grep -oE "invalid\":[0-9]+" | grep -oE "[0-9]+")
    canUse=$(cat $workdir/jifeninfo.log1 | grep -oE "canUse\":[0-9]+" | grep -oE "[0-9]+")
    #
    availablescore=$(cat $workdir/jifeninfo.log2 | grep -oE "availablescore\":\"[0-9]+" | grep -oE "[0-9]+")
    invalidscore=$(cat $workdir/jifeninfo.log2 | grep -oE "invalidscore\":\"[0-9]+" | grep -oE "[0-9]+")
    addScore=$(cat $workdir/jifeninfo.log2 | grep -oE "addScore\":\"[0-9]+" | grep -oE "[0-9]+")
    decrScore=$(cat $workdir/jifeninfo.log2 | grep -oE "decrScore\":\"[0-9]+" | grep -oE "[0-9]+")
    # 今日奖励积分
    today="$(date +%Y-%m-%d)" && todayscore=0
    todayscorelist=($(cat $workdir/jifeninfo.log2 | grep -oE "createTime\":\"$today[^}]*" | grep 'books_oper_type":"0"' | grep -oE "books_number\":[0-9]+" | grep -oE "[0-9]+" | tr "\n" " "))
    for ((i = 0; i < ${#todayscorelist[*]}; i++)); do todayscore=$((todayscore+todayscorelist[i])); done
    # 昨日奖励积分
    yesterday="$(date -d "1 days ago" +%Y-%m-%d)" && yesterdayscore=0
    yesterdayscorelist=($(cat $workdir/jifeninfo.log2 | grep -oE "createTime\":\"$yesterday[^}]*" | grep 'books_oper_type":"0"' | grep -oE "books_number\":[0-9]+" | grep -oE "[0-9]+" | tr "\n" " "))
    for ((i = 0; i < ${#yesterdayscorelist[*]}; i++)); do yesterdayscore=$((yesterdayscore+yesterdayscorelist[i])); done
    # info
    echo $(echo ${username:0:2}******${username:9}) 总积分:$total 本月将过期积分:$invalid 可用积分:$canUse 奖励积分:$availablescore 本月将过期奖励积分:$invalidscore 本月新增奖励积分:$addScore 本月消耗奖励积分:$decrScore 昨日奖励积分:$yesterdayscore 今日奖励积分:$todayscore
}

function otherinfo() {
    # 需传入参数 otherinfo
    echo ${all_parameter[*]} | grep -qE "otherinfo" || return 0
    echo && echo starting otherinfo...
    echo $(echo ${username:0:2}******${username:9}) >$workdir/otherinfo.info
    # 套餐
    curl -m 10 -X POST -sA "$UA" -b $workdir/cookie --data "mobile=$username" https://m.client.10010.com/mobileservicequery/operationservice/queryOcsPackageFlowLeftContent >$workdir/otherinfo.log
    addUpItemName=($(cat $workdir/otherinfo.log | grep -oE "addUpItemName\":\"[^\"]*" | cut -f3 -d\" | tr "\n" " "))
    endDate=($(cat $workdir/otherinfo.log | grep -oE "endDate\":\"[^\"]*" | cut -f3 -d\" | tr "\n" " "))
    remain=($(cat $workdir/otherinfo.log | grep -oE "remain\":\"[^\"]*" | cut -f3 -d\" | tr "\n" " "))
    for ((i = 0; i < ${#addUpItemName[*]}; i++)); do echo ${addUpItemName[i]}-${endDate[i]}-${remain[i]} >>$workdir/otherinfo.info; done
    # 话费
    curl -m 10 -X POST -sLA "$UA" -b $workdir/cookie --data "channel=client" https://m.client.10010.com/mobileservicequery/balancenew/accountBalancenew.htm >$workdir/otherinfo.log
    curntbalancecust=$(cat $workdir/otherinfo.log | grep -oE "curntbalancecust\":\"-?[0-9,]+\.[0-9]+" | cut -f3 -d\")
    realfeecust=$(cat $workdir/otherinfo.log | grep -oE "realfeecust\":\"-?[0-9,]+\.[0-9]+" | cut -f3 -d\")
    echo 可用余额:$curntbalancecust 实时话费:$realfeecust >>$workdir/otherinfo.info
    #
    cat $workdir/otherinfo.info
}

function freescoregift() {
    # 定向积分免费商品信息,需传入参数 freescoregift
    echo ${all_parameter[*]} | grep -qE "freescoregift" || return 0
    echo && echo starting freescoregift...
    echo $(echo ${username:0:2}******${username:9}) >$workdir/freescoregift.info
    # 限量免费领取商品
    big_SHELF_ID=8a29ac8975c327170175e40901610c77
    curl -m 10 -X POST -sLA "$UA" -b $workdir/cookie --data "reqsn=&reqtime=$(date +%s)$(shuf -i 100-999 -n 1)&cliver=&reqdata=%7B%7D" "https://m.client.10010.com/welfare-mall-front/mobile/show/getShelvesInfoDetail/v2?relevanceId=$big_SHELF_ID&sort=&category=2&goodsSkuId=undefined" >$workdir/freescoregift.log
    goods_NAME=($(cat $workdir/freescoregift.log | grep -oE "goods_NAME\":\"[^\"]+" | cut -f3 -d\" | tr "\n" " "))
    shop_INTEGRAL=($(cat $workdir/freescoregift.log | grep -oE "shop_INTEGRAL\":\"[^\"]+" | cut -f3 -d\" | tr "\n" " "))
    for ((i = 0; i < ${#goods_NAME[*]}; i++)); do echo ${goods_NAME[i]}-需要定向积分-${shop_INTEGRAL[i]} >>$workdir/freescoregift.info; done
    #
    cat $workdir/freescoregift.info
}

function tgbotinfo() {
    # TG_BOT通知消息: 未设置相应传入参数时不执行,传入参数格式 token@*** chat_id@*** | google search: telegram bot token chat_id
    echo ${all_parameter[*]} | grep -qE "token@[a-zA-Z0-9:_-]+" && token="$(echo ${all_parameter[*]} | grep -oE "token@[a-zA-Z0-9:_-]+" | cut -f2 -d@)" || return 0
    echo ${all_parameter[*]} | grep -qE "chat_id@[0-9-]+" && chat_id="$(echo ${all_parameter[*]} | grep -oE "chat_id@[0-9-]+" | cut -f2 -d@)" || return 0
    echo && echo starting tgbotinfo...
    unset tgsimple sendit
    
    # 简约通知信息，需要传入参数 tgsimple
    echo ${all_parameter[*]} | grep -qE "tgsimple" && tgsimple=true
    if [[ $tgsimple == "true" ]]; then
        echo ${userlogin_ook[u]} ${#userlogin_ook[*]} Accomplished. ${userlogin_err[u]} ${#userlogin_err[*]} Failed. >$workdir/tgsimple.info
        echo ${all_parameter[*]} | grep -qE "otherinfo"     && echo 可用余额:$curntbalancecust 实时话费:$realfeecust >>$workdir/tgsimple.info
        echo ${all_parameter[*]} | grep -qE "jifeninfo"     && echo 积分:$total-$availablescore-$todayscore >>$workdir/tgsimple.info
        echo ${all_parameter[*]} | grep -qE "freescoregift" && echo 定向积分免费商品数量:$(cat $workdir/freescoregift.info | tail -n +3 | grep -cv '^$') >>$workdir/tgsimple.info
        echo ${all_parameter[*]} | grep -qE "hfgoactive"    && echo 话费购奖品: $(cat $workdir/hfgoactive.info | tail -n +2) >>$workdir/tgsimple.info >>$workdir/tgsimple.info
        cat $workdir/tgsimple.info
        text="$(cat $workdir/tgsimple.info)"
        curl -m 10 -sX POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&text=$text" >/dev/null; sleep 3
        return 0
    fi
    
    # 登录状态
    text="$(echo ${userlogin_err[u]} ${#userlogin_err[*]} Failed. ${userlogin_ook[u]} ${#userlogin_ook[*]} Accomplished.)"
    curl -m 10 -sX POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&text=$text" >/dev/null; sleep 3
    
    # 积分信息
    text="$(echo $(echo ${username:0:2}******${username:9}) 总积分:$total 本月将过期积分:$invalid 可用积分:$canUse 奖励积分:$availablescore 本月将过期奖励积分:$invalidscore 本月新增奖励积分:$addScore 本月消耗奖励积分:$decrScore 昨日奖励积分:$yesterdayscore 今日奖励积分:$todayscore)"
    echo ${all_parameter[*]} | grep -qE "jifeninfo" && sendit=sendit || sendit=""
    [[ $sendit == "sendit" ]] && curl -m 10 -sX POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&text=$text" >/dev/null; sleep 3
    
    # hfgoactive
#    text="$(cat $workdir/hfgoactive.info)"
#    echo ${all_parameter[*]} | grep -qE "hfgoactive" && sendit=sendit || sendit=""
#    [[ $sendit == "sendit" ]] && curl -m 10 -sX POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&text=$text" >/dev/null; sleep 3
    
    # otherinfo
    text="$(cat $workdir/otherinfo.info)"
    echo ${all_parameter[*]} | grep -qE "otherinfo" && sendit=sendit || sendit=""
    [[ $sendit == "sendit" ]] && curl -m 10 -sX POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&text=$text" >/dev/null; sleep 3
    	
    if [ $u == $((${#all_username_password[*]}-1)) ]; then
    # freescoregift
    text="$(cat $workdir/freescoregift.info)"
    echo ${all_parameter[*]} | grep -qE "freescoregift" && sendit=sendit || sendit=""
    [[ $sendit == "sendit" ]] && curl -m 10 -sX POST "https://api.telegram.org/bot$token/sendMessage" -d "chat_id=$chat_id&text=$text" >/dev/null; sleep 3
    fi
}

function main() {
    for ((u = 0; u < ${#all_username_password[*]}; u++)); do 
        sleep $(shuf -i 1-10 -n 1)
        username=${all_username_password[u]%@*} && password=${all_username_password[u]#*@}
        UA="Mozilla/5.0 (Linux; Android 11; MI 9 Build/RKQ1.200826.002; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/87.0.4280.141 Mobile Safari/537.36; unicom{version:android@$unicom_version,desmobile:$username};devicetype{deviceBrand:Xiaomi,deviceModel:MI 9}"
        workdir="${workdirbase}_${username}" && [[ ! -d "$workdir" ]] && mkdir -p $workdir
        userlogin && userlogin_ook[u]=$(echo ${username:0:2}******${username:9}) || { userlogin_err[u]=$(echo ${username:0:2}******${username:9}); continue; }
        membercenter
        liulactive
        libaollactive
        hfgoactive
        jifeninfo
        otherinfo
        freescoregift
        tgbotinfo
    done
    echo && echo $(date) ${userlogin_err[*]} ${#userlogin_err[*]} Failed. ${userlogin_ook[*]} ${#userlogin_ook[*]} Accomplished.
    #rm -rf ${workdirbase}_*
}

main