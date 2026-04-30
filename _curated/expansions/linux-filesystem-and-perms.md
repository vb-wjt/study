# Linux 文件系统与权限速查

标签:`[就绪]` `[需补充]` `[盲点]`⚠️

> 你的 `file/unclassified/linux-privilege.md` (35 行) 写了 rwx 权限和 chmod,但**缺**:
> - 文件系统树状结构 (FHS)
> - 特殊权限的细节 (SUID / SGID / 粘滞位,你标了 todo)
> - 用户与组管理
> - 软链接 / 硬链接
> - 常用命令速查
>
> 这份文档**补全**这些。已写过的部分(rwx 数字 / chmod 用法)我不重复。
>
> 适合作为你 `linux-privilege.md` 的扩展版,可以归位到 `file/3-tech_stack/os/linux/`(目前 `3-tech_stack/` 下没有 OS 子分类,你可以新建)。

---

## 1. Linux 文件系统层次标准 (FHS)

> 大致按"根目录 / 下面有什么"理解。**面试不一定深入,但实战必备**。

```
/                   根目录
├── bin/            essential 用户命令(ls / cp / mv 等),所有用户都能执行
├── sbin/           essential 系统命令(fdisk / iptables 等),通常只 root 能执行
├── boot/           启动文件(kernel + initrd + grub)
├── dev/            设备文件(/dev/sda1, /dev/null, /dev/random)
├── etc/            系统配置(/etc/passwd, /etc/hosts, /etc/nginx/)
├── home/           用户家目录(/home/alice, /home/bob)
├── root/           root 用户的家目录(注意:不是 /home/root)
├── lib/, lib64/    系统库
├── tmp/            临时文件,通常重启会清理
├── usr/            非 essential 软件(/usr/bin, /usr/local/, /usr/share/)
│   ├── bin/        用户程序
│   ├── lib/        程序库
│   ├── local/      手动安装的软件(apt 不会动这里)
│   └── share/      共享数据(文档 / 图标)
├── var/            可变数据(/var/log, /var/lib, /var/spool)
│   ├── log/        日志文件
│   ├── lib/        程序状态(数据库 / 包管理)
│   └── spool/      队列(打印 / mail)
├── opt/            第三方软件(/opt/jdk, /opt/idea)
├── proc/           虚拟文件系统(进程信息,/proc/<pid>/)
├── sys/            虚拟文件系统(内核 / 设备信息)
├── srv/            服务数据
├── mnt/            临时挂载点(手动 mount)
├── media/          可移动媒体挂载点(USB 自动 mount 到这里)
└── run/            运行时数据(socket / pid 文件)
```

> **常见误区**:
> - `/usr` 不是 user,是 **U**nix **S**ystem **R**esources
> - `/var` 是 **var**iable,数据会变(日志 / 数据库)
> - `/opt` 是 **opt**ional,第三方软件常用

### 1.1 实战常用路径

| 你做什么 | 去哪 |
|---|---|
| 看应用日志 | `/var/log/` (系统) 或应用自己的目录 |
| 改 SSH 配置 | `/etc/ssh/sshd_config` |
| 看 Java 进程 | `/proc/<pid>/` 下能看 cmdline / status / fd 等 |
| 装的软件在哪 | `which <command>` 或 `ls /usr/local/bin/` |
| 系统启动什么服务 | `systemctl list-units` 或看 `/etc/systemd/system/` |
| 内存信息 | `cat /proc/meminfo` |
| CPU 信息 | `cat /proc/cpuinfo` |

---

## 2. 权限补全:特殊权限 (你标了 todo)

> rwx 三组权限你已经懂了,这里补**特殊权限 3 种**。

### 2.1 SUID (Set User ID)

权限位:`s` (替换所有者的 x 位),数字 `4`

**作用**: 以**文件所有者的身份**执行,而不是当前用户。

**经典例子**:`/usr/bin/passwd`
```bash
$ ls -l /usr/bin/passwd
-rwsr-xr-x 1 root root 68208 Jul 14  2023 /usr/bin/passwd
   ↑
   s = SUID,普通用户运行 passwd 时**临时获得 root 权限**(才能改 /etc/shadow)
```

**设置**:
```bash
chmod u+s file        # 加 SUID
chmod 4755 file       # 数字方式 (4 在最高位)
```

**风险**: 自己写的程序加 SUID + root 所有 = **巨大安全漏洞**。慎用。

### 2.2 SGID (Set Group ID)

权限位:`s` (替换组的 x 位),数字 `2`

**对文件**:以**文件所属组的身份**执行(类似 SUID)
**对目录** ⭐ (更常用):**新建文件继承所属组**

```bash
mkdir /shared && chmod 2775 /shared
# 然后 alice / bob 在 /shared 下新建文件,文件组都自动是 /shared 的组
# 用于团队协作目录
```

### 2.3 粘滞位 (Sticky Bit)

权限位:`t` (替换 others 的 x 位),数字 `1`

**对目录**:目录里的文件**只能被所有者删除**(即使其他人有写权限)。

**经典例子**: `/tmp`
```bash
$ ls -ld /tmp
drwxrwxrwt 19 root root 4096 Apr 30 10:15 /tmp
        ↑
        t = sticky,你能在 /tmp 创建文件,但别人不能删你的
```

**设置**:
```bash
chmod +t dir
chmod 1777 dir
```

### 2.4 数字组合

```
特殊权限位:  4 (SUID) | 2 (SGID) | 1 (Sticky)
普通权限:   421 421 421  (rwx rwx rwx for u/g/o)

例:
chmod 4755  → SUID + rwxr-xr-x   (passwd 这种)
chmod 2755  → SGID + rwxr-xr-x   (协作目录)
chmod 1777  → Sticky + rwxrwxrwx (类似 /tmp)
chmod 6755  → SUID+SGID + rwxr-xr-x (4+2)
```

---

## 3. 用户与组

### 3.1 关键文件

| 文件 | 内容 |
|---|---|
| `/etc/passwd` | 用户列表(用户名:UID:GID:全名:家目录:shell) |
| `/etc/shadow` | 密码哈希(只 root 可读) |
| `/etc/group` | 组列表(组名:GID:成员) |
| `/etc/sudoers` | sudo 权限配置(用 `visudo` 编辑) |

### 3.2 常用命令

```bash
# 用户
useradd -m -s /bin/bash alice    # 创建用户(-m 建家目录,-s 指定 shell)
usermod -aG developers alice      # 加入组(-a 追加,不覆盖原有的)
passwd alice                      # 改密码
userdel -r alice                  # 删用户(-r 一起删家目录)

# 组
groupadd developers
gpasswd -a alice developers       # 加用户到组(等同 usermod -aG)
gpasswd -d alice developers       # 移出组

# 查询
id alice                          # 看 alice 的 UID / GID / 所有组
groups alice                      # 看 alice 在哪些组
whoami                            # 当前用户
```

### 3.3 sudo

`sudo` 让普通用户**临时**以其他用户(默认 root)身份执行命令。

```bash
sudo apt install nginx           # 临时 root
sudo -u alice command            # 以 alice 身份
sudo -i                          # 切换到 root shell
```

`/etc/sudoers` 配置(用 `visudo` 编辑,会语法检查):

```
# 用户 alice 在所有主机以所有用户身份运行所有命令,且不需要密码
alice ALL=(ALL:ALL) NOPASSWD:ALL

# %wheel 组所有用户可 sudo 任何命令
%wheel ALL=(ALL) ALL
```

---

## 4. 软链接 vs 硬链接

| | 软链接 (symbolic link) | 硬链接 (hard link) |
|---|---|---|
| 实际是 | 一个**指向另一个文件路径**的"快捷方式" | **同一个 inode**的另一个名字 |
| 跨文件系统 | ✓ | ✗ |
| 链接到目录 | ✓ | ✗ (除了 root,通常禁) |
| 原文件删除 | 链接失效("断链") | 链接还在,数据还在 |
| 创建命令 | `ln -s 原 链` | `ln 原 链` |

```bash
ln -s /opt/idea/bin/idea.sh /usr/local/bin/idea  # 软链
ln /home/alice/file.txt /home/bob/copy.txt        # 硬链
ls -li                                             # 看 inode 号(硬链相同)
```

---

## 5. 常用文件操作命令(进阶)

### 5.1 查找

```bash
find /etc -name "*.conf"               # 按名找
find / -size +100M                     # 大于 100MB
find / -mtime -7                       # 7 天内修改
find /var/log -type f -name "*.log" -delete  # 找了直接删

locate nginx.conf                      # 快(基于数据库,需 updatedb)
which java                             # 找命令在 PATH 里的位置
whereis java                           # 找命令 + 帮助 + man 页
```

### 5.2 文件内容

```bash
cat file.txt                           # 全部
less file.txt                          # 分页(/搜索, n 下一个, q 退出)
head -n 20 file.txt                    # 前 20 行
tail -n 20 file.txt                    # 后 20 行
tail -f /var/log/app.log               # 实时跟踪(看日志必备)

grep -r "pattern" /path                # 递归搜索
grep -i "pattern" file                 # 忽略大小写
grep -v "pattern" file                 # 反向(不匹配的)
grep -A 3 -B 3 "pattern" file          # 上下文(after/before)

awk '{print $1, $3}' file              # 按列处理(空白分隔,$1 第一列)
sed 's/old/new/g' file                 # 替换(g = 全局)
sed -i 's/old/new/g' file              # 直接改文件(-i)

wc -l file                             # 行数
sort file | uniq -c | sort -rn         # 按出现次数排序
```

### 5.3 进程与服务

```bash
ps aux                                 # 看所有进程
ps -ef | grep java                     # 找 java 进程
top                                    # 动态进程监控
htop                                   # top 的彩色增强版

kill <pid>                             # 软杀(SIGTERM)
kill -9 <pid>                          # 强杀(SIGKILL)
killall java                           # 按名字杀

systemctl status nginx                 # 看服务状态
systemctl start/stop/restart nginx     # 启停
systemctl enable/disable nginx         # 开机启动
systemctl list-units --type=service    # 列所有 service
journalctl -u nginx -f                 # 看 systemd 服务日志
```

### 5.4 网络

```bash
ip a                                    # 看 IP(替代旧的 ifconfig)
ip route                                # 看路由表
ss -tunlp                               # 看监听端口(替代旧的 netstat)
ss -tn state established                # 看已建立的 TCP 连接

curl -v https://example.com             # 详细 HTTP 请求
curl -X POST -d '{"k":"v"}' -H 'Content-Type: application/json' http://...
wget URL                                # 下载文件

ping -c 4 example.com                   # 4 次 ping 后停
traceroute example.com                  # 跟踪路由
nslookup example.com / dig example.com  # DNS 查询
```

### 5.5 磁盘

```bash
df -h                                   # 看分区使用(human readable)
du -sh /var/log/*                       # 看目录大小
du -sh * | sort -h                      # 当前目录子项,按大小排
ncdu /                                  # 交互式磁盘分析(强烈推荐装这个)

mount | column -t                       # 看挂载情况
mount /dev/sdb1 /mnt/data               # 临时挂载
umount /mnt/data                        # 卸载
```

---

## 6. 你的 SI/PI 工程里 Linux 出现的地方

| 场景 | 你工程里的引用 |
|---|---|
| PI 4.0 部署目标 | "Windows 主 + Linux 辅",refactor_pi/docs |
| Trellis Agent 路径 | `/var/opt/VertivBackup`(Linux 备份路径) |
| FerretDB 调研 | Linux 是首选(Win 编译失败的对比) |
| Zero Engine 部署 | [TODO: 你确认是 Linux 还是双平台] |

---

## 7. 你应该再补的(我没经验,你有)

| 主题 | 你补什么 |
|---|---|
| 你工程里 Linux 实战 | Vertiv 部署用什么发行版?CentOS/RHEL/Ubuntu? |
| 容器化 | Docker / Podman 你日常用吗? |
| 运维脚本 | 你有没写过 shell 脚本(自动化部署 / 巡检)? |
| 文件系统 | ext4 / XFS / Btrfs 的差异有没考虑过? |
| 权限实战 | 你最近一次解决"权限不对"是什么场景? |
| systemd 服务 | 你见过 PI / SI 的 systemd unit file 吗? |

---

## 8. 与你 `file/` 其他素材的链接

| 主题 | 我提到的 | 你的源文 |
|---|---|---|
| rwx 权限 + chmod | (本文已避免重复) | `file/unclassified/linux-privilege.md` |
| FHS 文件系统结构 | §1 | (无) |
| 特殊权限细节 | §2 | 你 linux-privilege.md §1 标了 todo |

---

> **下一步**: [`snmp4j-quickref.md`](./snmp4j-quickref.md) (SI 用得最多的库,你竟然没沉淀)
