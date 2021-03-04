> 登录 签到 会员任务  
新增使用github自动运行，无需自己的服务器
## 使用方法

### 1.Fork 本仓库

### 2.添加secret
设置 `PARAMETER` 的值为脚本支持的参数，间隔符使用空格即可。  
进入仓库后点击 `Settings`，右侧栏点击 `Secrets`，点击 `New secret`。添加 `PARAMETER` 的值，为脚本支持的参数如： `githubaction membercenter jifeninfo otherinfo 12345678901@112233 01234567891@123456 appId@247b001385de5cc6ce11731ba1b15835313d489d604e58280e455a6c91e5058651acfb0f0b77029c2372659c319e02645b54c0acc367e692ab24a546b83c302d`  

#### Secrets参数 `PARAMETER` 具体说明:
| 参数 |  说明  |
| -------- | ----- |
| `membercenter` |   加入这个表示会运行除激活流量包的所有签到活动，无则不会签到|
| `githubaction` |   使用github action运行则必须添加以设置目录|
| `jifeninfo` |   加入这个表示会运行号码积分信息查询|
| `otherinfo` |   加入这个表示会运行号码及其它信息如套餐及话费查询|
| `freescoregift` |   加入这个表示会运行定向积分免费商品信息查询|
| ~~hfgoactive~~ |   加入这个表示会运行话费购活动，但境外ip貌似不能联通，所以不添加|
| `12345678901@112233` |   为 11位手机号码@6位服务密码，有多个手机号则依次添加即可|
| `appId@xxxx` |   其中xxxx为appld值，具体可抓包或者安卓使用下面的方法获得|
| `liulactive@d@ff80808166c5ee6701676ce21fd14716` |   为流量包激活激活所需参数，中间d表示每天,w表示每周一,m代表每月第二天，ff80~4716为1g流量日包id值。比如左边参数代表为所有手机号每天激活一个1g流量日包|
| `liulactive@d@ff80808166c5ee6701676ce21fd14716@13012341234-18812341234` |   代表仅为手机号13012341234和18812341234每天激活一个1g流量日包，其余手机号不执行流量包激活|
| `libaollactive@d` |   为`我的礼包` 里面的流量包激活激活所需参数，后面d表示每天,w表示每周一,m代表每月第一天。比如左边参数代表为所有手机号每天激活一个 `我的礼包` 里面的排在第一位的流量包|
| `libaollactive@d@13012341234-18812341234` |   代表仅为手机号13012341234和18812341234每天激活一个 `我的礼包` 里面的排在第一位的流量包，其余手机号不执行流量包激活|
| `token@*** chat_id@***` |   为telegram bot通知所需参数，无则不进行信息通知|
| `tgsimple` |   为tg bot简洁通知所需参数，无则为详细信息通知|

##### 各流量包id具体值：
| 流量包名 |  id值  |
| -------- | ----- |
| 1GB日包 |   `ff80808166c5ee6701676ce21fd14716`|
| 2GB日包 |   `21010621565413402`|
| 5GB日包 |   `21010621461012371`|
| 10GB日包 |   `21010621253114290`|
| 4GB流量七日包 |   `20080615550312483`|
| 100MB全国流量月包 |   `ff80808165afd2960165d1eb75424667`|
| 300MB全国流量月包 |   `ff80808165afd2960165d1e93423464a`|
| 500MB全国流量月包 |   `ff80808165afd2960165cdbf4a950c1c`|
| 1GB全国流量月包 |   `ff80808165afd2960165cdbc92470bef`|

##### appld值获取：
`247b001385de5cc6ce11731ba1b15835313d489d604e58280e455a6c91e5058651acfb0f0b77029c2372659c319e02645b54c0acc367e692ab24a546b83c302d`为联通app抓包的appid值  <不保证这个appid能用，所以最好自己抓包，如果运行登录失败大概率就是appid不对或者失效>  
以下获取appid方法由群友提供：安卓不会抓包的就去手机文件管理器，目录路径为 `Unicom/appid` ，打开复制就行了。  

**填入参数举例**：  
`githubaction membercenter 号码1@密码1 号码2@密码2 号码3@密码3 appId@xxxx` 代表号码1、2和3进行正常签到  
`githubaction membercenter 号码1@密码1 号码2@密码2 号码3@密码3 appId@xxxx liulactive@d@xxxx` 代表号码1、2和3进行正常签到且每天为所有号码激活id值为xxxx的流量包  
`githubaction membercenter 号码1@密码1 号码2@密码2 号码3@密码3 appId@xxxx liulactive@w@xxxx@号码1-号码2` 代表号码1、2和3进行正常签到且每周一仅为号码1和2激活id值为xxxx的流量包  
`githubaction 号码1@密码1 号码2@密码2 号码3@密码3 appId@xxxx liulactive@m@xxxx` 代表每月2号为所有号码激活id值为xxxx的流量包，不进行签到活动  

运行开始时间也可以自己修改`.github/workflows/签到.yml`文件中`- cron: 05 23 * * *`，你想运行的北京时间减8就行了。05代表5分，23代表23时，就是0时区23：05的意思。

触发运行方式：  
双击右上角自己仓库Star触发；  
Actions栏手动运行；  
由于规则更新,可能会Fork后会默认禁用,请手动点击Actions 选择项目 `enable workflows`激活  

### 3.同步Fork后的代码

#### 手动同步

[手动同步 https://blog.blueskyclouds.com/jsfx/58.html](https://blog.blueskyclouds.com/jsfx/58.html)

#### 自动同步

##### 方案A - 强制远程分支覆盖自己的分支
1. 参考[这里](https://github.com/BlueskyClouds/My-Actions/blob/master/backUp/gitSync.md)，安装[pull插件](https://github.com/apps/pull)，并确认此项目已在pull插件的作用下（参考文中1-d）。
2. 确保.github/pull.yml文件正常存在，yml内上游作者填写正确(此项目已填好，无需更改)。
3. 将pull.yml里面的`mergeMethod: merge`修改为`mergeMethod: hardreset`保存。
4. ENJOY!上游更改三小时左右就会自动发起同步。

##### 方案B - 保留自己分支的修改

> 上游变动后pull插件会自动发起pr，但如果有冲突需要自行**手动**确认。
> 如果上游更新涉及workflow里的文件内容改动，需要自行**手动**确认。

1. 参考[这里](https://github.com/BlueskyClouds/My-Actions/blob/master/backUp/gitSync.md)，安装[pull插件](https://github.com/apps/pull)，并确认此项目已在pull插件的作用下（参考文中1-d）。
2. 确保.github/pull.yml文件正常存在，yml内上游作者填写正确(此项目已填好，无需更改)。
3. 确保pull.yml里面是`mergeMethod: merge`(默认就是merge)。
4. ENJOY!上游更改三小时左右就会自动发起同步。

### 4.Actions日志删除
1. 在github保留太多日志不太好，首先可以去 `Settings` - `Actions` - `Artifact and log retention` 设置自己想要的保存天数。
2. 在Actions界面手动运行Delete old workflow runs，输入Number of days和Number of runs的数字，运行完毕后即只保留你设置的天数和项目剩余数。


## 各版本使用教程  
> [**CnUnicom.sh**](https://github.com/mixool/HiCnUnicom/blob/master/tutorial/CnUnicom_sh_readme.md)  
> [**UnicomGetCoin.py**](https://github.com/mixool/HiCnUnicom/blob/master/tutorial/UnicomAutoGetCoin_py_readme.md)  
  
