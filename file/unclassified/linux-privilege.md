### 权限

| 权限字符       | 数字表示 | 对文件的意义      | 对目录的意义      |
|------------|------|-------------|-------------|
| r(read)    | 4    | 读取文件内容      | 列出目录内容(ls)  |
| w(write)   | 2    | 修改文件内容      | 在目录中创建/删除文件 |
| x(execute) | 1    | 执行文件(程序/脚本) | 进入目录(cd)    |

特殊权限: SUID(4)、SGID(2)、粘滞位(1)  todo

解析
```shell
# 权限的三个身份组
-rwxr-xr-- 1 alice developers 1024 Jan 1 12:34 script.sh
# 所有者：alice (user)     → rwx
# 所属组：developers (group) → r-x  
# 其他用户：others          → r--
```



修改权限
```shell
# 1. 数字方式（最常用）
$ chmod 755 script.sh      # rwxr-xr-x
$ chmod 644 config.txt     # rw-r--r--
$ chmod 600 secret.key     # rw-------

# 2. 字符方式（u=用户, g=组, o=其他, a=所有）
$ chmod u+x script.sh      # 给所有者添加执行权限
$ chmod g-w file.txt       # 移除组的写权限
$ chmod o=r file.txt       # 设置其他用户只读
$ chmod a+x script.sh      # 给所有人添加执行权限
$ chmod u=rwx,g=rx,o=r script.sh  # 等同于 chmod 754

# 3. 特殊权限
$ chmod 4755 /usr/bin/myprogram   # 设置SUID
$ chmod 2755 /shared/directory    # 设置SGID
$ chmod 1777 /tmp                 # 设置粘滞位

# 4. 递归修改目录下所有文件
$ chmod -R 755 directory/         # 递归修改目录及其内容
$ chmod -R u=rwX,g=rX,o=rX dir/   # X: 只给目录执行权限，不给文件
```