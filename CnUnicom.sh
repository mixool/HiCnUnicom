#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
# Usage:
## wget --no-check-certificate https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh && chmod +x CnUnicom.sh && bash CnUnicom.sh 
### bash <(curl -s https://raw.githubusercontent.com/mixool/HiCnUnicom/master/CnUnicom.sh) ${username} ${password}

# alias curl
alias curl='curl -m 10'

# user info: change them to yours or use parameters instead.
username="$1"
password="$2"

# 联通APP版本
unicom_version=8.0100

# deviceId: 随机IMEI
deviceId=$(shuf -i 123456789012345-987654321012345 -n 1)

# 安卓手机端APP登录过的使用这个UA
UA="Mozilla/5.0 (Linux; Android 6.0.1; oneplus a5010 Build/V417IR; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/52.0.2743.100 Mobile Safari/537.36; unicom{version:android@$unicom_version,desmobile:$username};devicetype{deviceBrand:Oneplus,deviceModel:oneplus a5010}"

# 苹果手机端APP登录过的使用这个UA
#UA="ChinaUnicom4.x/176 CFNetwork/1121.2.2 Darwin/19.2.0"

# workdir
workdir="/var/log/CnUnicom_$username"
[[ ! -d "$workdir" ]] && mkdir $workdir

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

# 登录失败尝试修改以下这个appId的值为抓包获取的登录过的联通app
function login() {
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
&appId=247b001385de5cc6ce11731ba1b15835313d489d604e58280e455a6c91e5058651acfb0f0b77029c2372659c319e02645b54c0acc367e692ab24a546b83c302d
&keyVersion=1
&deviceBrand=Oneplus
&pip=10.0.$(shuf -i 1-255 -n 1).$(shuf -i 1-255 -n 1)
&provinceChanel=general
&version=android%40$unicom_version
&deviceModel=oneplus%20a5010
&deviceOS=android6.0.1
&deviceCode=$deviceId
EOF

    # cookie
    curl -X POST -sA "$UA" -b $workdir/cookie -c $workdir/cookie "https://m.client.10010.com/mobileService/customer/query/getMyUnicomDateTotle.htm?yw_code=&mobile=$username&version=android%40$unicom_version" | grep -oE "infoDetail" >/dev/null && status=0 || status=1
    [[ $status == 0 ]] && echo cookies登录$username成功
    
    if [[ $status == 1 ]]; then
        curl -X POST -sA "$UA" -c $workdir/cookie "https://m.client.10010.com/mobileService/logout.htm?&desmobile=$username&version=android%40$unicom_version" >/dev/null
        curl -sA "$UA" -b $workdir/cookie -c $workdir/cookie -d @$workdir/signdata "https://m.client.10010.com/mobileService/login.htm" >/dev/null
        token=$(cat $workdir/cookie | grep -E "a_token" | awk  '{print $7}')
        [[ "$token" = "" ]] && echo "Error, login failed." && echo "cmd for clean: rm -rf $workdir" && exit 1
        echo 密码登录$username成功
    fi
}

function openChg() {
    # 每月一号办理解除40G封顶业务
    [[ "$(date "+%d")" == "01" ]] || return 0
    echo; echo $(date) starting dingding OpenChg...
    curl -sA "$UA" -b $workdir/cookie --data "querytype=02&opertag=0" "https://m.client.10010.com/mobileService/businessTransact/serviceOpenCloseChg.htm" >/dev/null
}

function membercenter() {
    echo; echo $(date) starting membercenter...
    
    #获取文章和评论生成数组数据
    NewsListId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "pageNum=1&pageSize=10&reqChannel=00" https://m.client.10010.com/commentSystem/getNewsList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    comtId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    nickId=($(curl -X POST -sA "$UA" -b $workdir/cookie --data "id=${NewsListId[0]}&pageSize=10&pageNum=1&reqChannel=quickNews" -e "https://img.client.10010.com/kuaibao/detail.html?pageFrom=newsList&id=${NewsListId[0]}" https://m.client.10010.com/commentSystem/getCommentList | grep -oE "nickName\":\"[^\"]*" | awk -F[\"] '{print $NF}' | tr "\n" " "))
    Referer="https://img.client.10010.com/kuaibao/detail.html?pageFrom=${NewsListId[0]}"
   
    #评论点赞
    for((i = 0; i < ${#comtId[*]}; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=02&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=02&pointType=01&reqChannel=quickNews&reqId=${comtId[i]}&praisedMobile=${nickId[i]}&newsId=${NewsListId[0]}" -e "$Referer" https://m.client.10010.com/commentSystem/csPraise | grep -oE "growScore\":\"0\"" >/dev/null && break
    done
    
    #文章点赞
    for((i = 0; i <= ${#NewsListId[*]}; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=02&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise
        curl -X POST -sA "$UA" -b $workdir/cookie --data "pointChannel=01&pointType=01&reqChannel=quickNews&reqId=${NewsListId[i]}" https://m.client.10010.com/commentSystem/csPraise | grep -oE "growScore\":\"0\"" >/dev/null && break
    done
    
    #文章评论
    newsTitle="$(curl -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "mainTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    subTitle="$(curl -X POST -sA "$UA" -b $workdir/cookie --data "newsId=${NewsListId[1]}&reqChannel=quickNews&isClientSide=0&pageFrom=newsList" -e "$Referer" https://m.client.10010.com/commentSystem/getNewsDetails | grep -oE "subTitle\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
    for((i = 0; i <= 5; i++)); do
        data="id=${NewsListId[1]}&newsTitle=$(urlencode $newsTitle)&commentContent=$RANDOM&upLoadImgName=&reqChannel=quickNews&subTitle=$(urlencode $subTitle)&belongPro=098"
        mycomtId="$(curl -X POST -sA "$UA" -b $workdir/cookie --data "$data" -e "$Referer" https://m.client.10010.com/commentSystem/saveComment | grep -oE "id\":\"[^\"]*" | awk -F[\"] '{print $NF}')"
        curl -X POST -sA "$UA" -b $workdir/cookie --data "type=01&reqId=$mycomtId&reqChannel=quickNews" -e "$Referer" https://m.client.10010.com/commentSystem/delDynamic
    done
    
    #每月一次账单查询
    if [[ "$(date "+%d")" == "01" ]]; then
        curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.HistoryBill --data "yw_code=&desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryHistoryBill.htm?mobile_c_from=home" >/dev/null
        curl -sLA "$UA" -b $workdir/cookie.HistoryBill --data "operateType=0&bizCode=1000210003&height=889&width=480" "https://m.client.10010.com/mobileService/query/querySmartBizNew.htm?" >/dev/null
        curl -sLA "$UA" -b $workdir/cookie.HistoryBill --data "systemCode=CLIENT&transId=&userNumber=$username&taskCode=TA52554375&finishTime=$(date +%Y%m%d%H%M%S)" "https://act.10010.com/signinAppH/limitTask/limitTime" >/dev/null
    fi

    #每日一次余量查询
    curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.LeavePackage --data "desmobile=$username&version=android@$unicom_version" "https://m.client.10010.com/mobileService/common/skip/queryLeavePackage.htm" >/dev/null
    curl -sLA "$UA" -b $workdir/cookie.LeavePackage --data "operateType=0&bizCode=1000210026&height=776&width=480" "https://m.client.10010.com/mobileService/query/querySmartBizNew.htm?" >/dev/null
    curl -sLA "$UA" -b $workdir/cookie.LeavePackage --data "type=0" "https://m.client.10010.com/mobileService/grow/marginCheck.htm"
    
    #签到
    Referer="https://img.client.10010.com/activitys/member/index.html"
    data="yw_code=&desmobile=$username&version=android@$unicom_version"
    curl -sLA "$UA" -b $workdir/cookie -c $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/querySigninActivity.htm?$data" >/dev/null
    Referer="https://act.10010.com/SigninApp/signin/querySigninActivity.htm?$data"
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/daySign?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)"
    echo
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/todaySign"
    echo
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/addIntegralDA"
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/bannerAdPlayingLogo"
    ##三次金币抽奖， 每日最多可花费金币执行十三次
    usernumberofjsp=$(curl -sA "$UA" -b $workdir/cookie.SigninActivity https://m.client.10010.com/dailylottery/static/textdl/userLogin | grep -oE "encryptmobile=\w*" | awk -F"encryptmobile=" '{print $2}'| head -n1)
    for((i = 1; i <= 3; i++)); do
        [[ $i -gt 3 ]] && curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "goldnumber=10&banrate=10&usernumberofjsp=$usernumberofjsp" https://m.client.10010.com/dailylottery/static/doubleball/duihuan >/dev/null; sleep 1
        curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "usernumberofjsp=$usernumberofjsp&flag=convert" https://m.client.10010.com/dailylottery/static/doubleball/choujiang | grep -qE "用户机会次数不足" && break
    done
    echo; echo goldTotal：$(curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -e "$Referer" "https://act.10010.com/SigninApp/signin/getGoldTotal?vesion=0.$(shuf -i 1234567890123456-9876543210654321 -n 1)")
    
    ##积分抽奖首次免费，之后领300奖励积分兑换再抽奖,最多三十次
    curl -sLA "$UA" -b $workdir/cookie "https://m.client.10010.com/welfare-mall-front/mobile/winter/getpoints/v1"
    curl -X POST -sLA "$UA" -b $workdir/cookie --data "from=$(shuf -i 12345678901-98765432101 -n 1)" "https://m.client.10010.com/welfare-mall-front/mobile/winterTwo/getIntegral/v1"

    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang
    for((i = 1; i <= 3; i++)); do
        curl -sA "$UA" -b $workdir/cookie.SigninActivity --data "goldnumber=10&banrate=30&usernumberofjsp=$usernumberofjsp" http://m.client.10010.com/dailylottery/static/integral/duihuan >/dev/null; sleep 1
        curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "usernumberofjsp=$usernumberofjsp&flag=convert" http://m.client.10010.com/dailylottery/static/integral/choujiang | grep -qE "用户机会次数不足" && break
    done
    
    # 游戏签到积分 每日1积分
    curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "methodType=iOSIntegralGet&gameLevel=1&deviceType=iOS" "https://m.client.10010.com/producGameApp"
    
    # 奖励积分
    echo; curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity --data "methodType=signin" https://m.client.10010.com/producGame_signin
    
    # 游戏宝箱
    curl -X POST -sA "$UA"  -b $workdir/cookie.SigninActivity -c $workdir/cookie.xybx --data "thirdUrl=https%3A%2F%2Fimg.client.10010.com%2Fshouyeyouxi%2Findex.html%23%2Fyouxibaoxiang" https://m.client.10010.com/mobileService/customer/getShareRedisInfo.htm >/dev/null
    echo; curl -X POST -sA "$UA" -b $workdir/cookie.xybx --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=N" https://m.client.10010.com/game_box
    echo; curl -sA "$UA" -b $workdir/cookie.xybx --data "methodType=taskGetReward&deviceType=Android&clientVersion=$unicom_version&taskCenterId=98" https://m.client.10010.com/producGameTaskCenter
    echo; curl -X POST -sA "$UA" -b $workdir/cookie.xybx --data "methodType=reward&deviceType=Android&clientVersion=$unicom_version&isVideo=Y" https://m.client.10010.com/game_box
    
#沃之树浇水
    #curl -X POST -sA "$UA" -b $workdir/cookie.SigninActivity -c $workdir/cookie.wotree --data "thirdUrl=https%3A%2F%2Fimg.client.10010.com%2Fmactivity%2FwoTree%2Findex.html%23%2F" https://m.client.10010.com/mobileService/customer/getShareRedisInfo.htm >/dev/null
    #Referer="https://img.client.10010.com/mactivity/woTree/index.html"
    #curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/mailb/isNewLetter.htm >/dev/null
    #curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/task/bord.htm >/dev/null
    #curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/arbordayJson/index.htm >/dev/null
    #curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/arbordayJson/getChanceByIndex.htm?index=0 >/dev/null
    #curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/stealingEnergy/engerSign.htm >/dev/null
    #echo; curl -X POST -sA "$UA" -b $workdir/cookie.wotree -c $workdir/cookie.wotree -e "$Referer" https://m.client.10010.com/mactivity/arbordayJson/arbor/3/0/3/grow.htm | grep -oE "addedValue\":[0-9]"
    
    #获得流量
    for((i = 1; i <= 3; i++)); do
        curl -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=22" https://act.10010.com/SigninApp/mySignin/addFlow >/dev/null; sleep 5
        curl -X POST -sA "$UA" -b $workdir/cookie --data "stepflag=23" https://act.10010.com/SigninApp/mySignin/addFlow | grep -oE "reason\":\"01\"" >/dev/null && break
    done
}

function main() {
    #sleep $(shuf -i 1-10800 -n 1)
    login
    membercenter
    #openChg
    #rm -rf $workdir
    echo; echo $(date) $username Accomplished.  Thanks!
}

main

