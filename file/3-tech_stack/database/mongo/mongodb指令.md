1.基础操作
=======

1.1. 对比MySQL
------------

```
MySQL数据库 database ---> Mongodb数据库 database

MySQL数据表 table ---> Mongodb集合 Collection

MySQL记录 records ---> Mongodb文档 document

MySQL需要在建表的时候，确认表结构，有多少个字段，字段是什么类型，长度是多少，后续新增、修改、删除都需要再次修改表结构，同时需要考虑表中已经存在的数据

Mongodb在建立集合的时候，不用确认结构，字段等，是按照BSON（类似JSON）的数据来存储的。可以动态添加字段，适应快速变化的数据模型；支持嵌套文档和数组，允许复杂的数据结构。

Mongodb 通过副本集（Replica Set）实现数据的高可用；通过分片（Sharding）实现水平扩展，支持大规模数据储存和高吞吐量。

Mongodb 适用于需要处理大量数据和实时数据分析的场景，如物联网数据，点击流数据；内容管理系统、博客、社交网络等需要灵活数据模型的应用；适用于需要快速迭代和灵活数据结构的移动应用和游戏后端。

这两者的索引底层都是B+树。Mongodb 对于事务一致性的支持不如MySQL
```

1.2. 创建集合
---------

    // 1. 创建
    db.createCollection("test1")
    
    // 不存在test1集合时会自动创建
    use test1  
    
    // 2. 删除
    db.test1.drop()
    
    
    // 3. 查看
    show collections

1.3. 插入文档
---------

    db.test.insertOne({"name" : "wu", "age" : "24"})
    
    db.test.insertMany([
      {  
        "name": "Jane1",  
        "age": 25,  
        "email": "janesmith@example.com"  
      },  
      {  
        "name": "Bob1",  
        "age": 40,  
        "email": "bobjohnson@example.com"  
      },
      {  
        "name": "Jane2",  
        "age": 26,  
        "email": "janesmith@example.com"  
      },  
      {  
        "name": "Bob2",  
        "age": 41,  
        "email": "bobjohnson@example.com"  
      }  
    ])
    
    
    db.test.insertMany([
      {  
        "name": "order1",  
        "items" : [
            {"num" : 1, "price" : 100},
            {"num" : 2, "price" : 100},
            {"num" : 3, "price" : 100},
            {"num" : 4, "price" : 100},
            {"num" : 5, "price" : 100}
        ]  
      },  
      {  
        "name": "order2",  
        "items" : [
            {"num" : 1, "price" : 1000},
            {"num" : 2, "price" : 1000},
            {"num" : 3, "price" : 1000}
        ]
      },
      {  
        "name": "order3",  
        "items" : [
            {"num" : 10, "price" : 1000},
            {"num" : 20, "price" : 1000},
        ]    
      }
    ])   
    // 插入的时候会生成一个 _id 来作为主键，同时加入到索引中
    // 如 ObjectId("668205c1e751d9043927bd72")  
    // _id 不想要生成的值，也可以在插入的时候指定值
    
    for(var i = 0; i < 100; i++){
      db.test.insertOne({"name" : "name" + i, "age" : i})
    }

1.4. 查找文档
---------

    // 1. 查询 test 集合中 name 为 Jane，同时 age 为 25 的文档 
    //（age 需要为插入时候的类型，不一致的话也不会转换(包括隐式转换)）
    db.test.find({"name" : "Jane", "age" : 25})
    
    // 2. 查询 test 集合中 name 为 Jane，同时 age 为 25 的文档, 并且只查询文档中的 name 字段
    // 有多少个设置为 1 (显示) 的就查询多少个，没有 1 的话就默认查询所有字段。 0 为不查询。
    // 返回部分字段的查询，也叫投影查询
    db.test.find({"name" : "Jane", "age" : 25}, {"name" : 1, "email" : 1, "_id" : 0})
    
    
    // 3. 查询 test 集合中 age > 30 的文档
    db.test.find({"age" : {$gt:30}})
    
    // 4. 查询 test 集合中 age 在 26, 27 的文档 （nin 不包括）
    db.test.find({"age" : {$in : [26, 27]}})
    
    
    // 5. 查询 test 集合中 name 为 Jane1, 并且 age 大于 25 的文档 （$or 或者）
    db.test.find({$and : [{"name" : "Jane1"}, {"age" : {$gt : 25}}]})

![](https://cdn.nlark.com/yuque/0/2024/png/42911816/1719800627016-1c8cd603-59c1-4ac5-8a4b-11c3c566e1cd.png)
1.5. 更新文档

---------

    // 1. 更新 test 集合中 name 为 Jane 的文档，用后面的 {} 中的替换文档,
    // 会导致原数据中的 email 不见了
    db.test.update({"name" : "Jane"}, {"name" : "Jane", "age" : 30})
    
    
    // 2. 更新 test 集合中 name 为 Jane 的文档，把文档的 age 更新为 35
    // 其他属性值不变，与 1. 区别开
    db.test.update({"name" : "Jane"}, {$set : {"age" : 35}})
    
    
    // 3. 更新 test 集合中 name 为 Jane 的文档，把文档的 age 加 1 （减一则为 -1）
    db.test.update({"name" : "Jane"}, {$inc : {"age" : 1}})
    
    
    // 4. 更新 test 集合中 name 为 Bob 的文档，把文档的 name 改为 Bob2, age 加一，
    // email 属性改为 e-mail, other 删除掉
    db.test.update({"name" : "Bob"}, {
      $set : {"name" : "Bob2"}, 
      $inc : {"age" : 1}, 
      $rename : {"email" : "e-mail"}, 
      $unset : {"other" : true}
    })
    
    
    
    // 5. 条件匹配不到的情况下，不会有操作
    db.test.update({"name" : "123"}, {$set : {"age" : 50}})
    // 执行结果：Updated 0 record(s) in 2ms
    
    
    // 6. 条件匹配不到，并且第三个参数值为 true 的话，则插入这条记录
    // 即是存在则更新，不存在则插入
    db.test.update({"name" : "123"}, {$set : {"age" : 50}}, true)
    
    
    // 7. 条件匹配成功，且有多条，并且第四个参数为 true (默认为 false) 的话，更新全部记录，
    // 否则只更新一条
    db.test.update({"age" : 50}, {$set : {"age" : 60}}, false, true)

![](https://cdn.nlark.com/yuque/0/2024/png/42911816/1719823842742-6af9c142-2feb-4459-a40d-dd1b423c9b26.png)
1.6. 删除文档

---------

    // 1. 删除 test 集合中的 age 大于 61 的文档，找到则只删除一条
    // 第二个参数默认为false, 删除匹配的所有文档
    db.test.remove({"age" : {$gt : 61}}, true)

1.7. 分页操作
---------

    // 1. 统计 test 集合中的文档数量
    db.test.find().count()
    
    // 2. 分页，查看前三条
    db.test.find().limit(3)
    
    // 3. 分页，查看从第二条开始的两条文档
    db.test.find().skip(1).limit(2)
    
    // 4. 把 test 集合中的文档，按照 age 属性 升序 排列（1：升序，-1：降序）
    db.test.find().sort({"age" : 1})
    
    // skip() limit() sort() 放到一起的时候，执行顺序是先 sort(), 再 skip(), 
    // 最后再 limit(), 和编写的顺序无关

[MongoDB基本操作(一)——简介、基本操作、增删改查-阿里云开发者社区](https://developer.aliyun.com/article/1162022)

[MongoDB常用命令详细讲解（最全）_mongodb命令-CSDN博客](https://blog.csdn.net/m0_65818274/article/details/134190196)



# 2.复杂查询

2.1. 正则
-------

    // 正则是用的 js 的写法
    // 1. 查询 test 集合中，name 字段 以 B 开头的文档
    db.test.find({"name" : /^B/})

2.2. 聚合
-------

    // 1. 根据 null 进行分组，并且统计每个分组里面包含文档的数量。也即是统计所有的文档数量。
    db.test.aggregate([
        {
            $group : {
                "_id" : null,
                "count" : {$sum : 1}            
            }
         }
    ])
    
    
    // 2. 根据 email 字段进行分组，并且统计每个分组里面包含文档的数量
    db.test.aggregate([
        {
            $group : {
                "_id" : "$email",
                "count" : {$sum : 1}            
            }
         }
    ])
    
    
    // 3. 根据 email 字段进行分组，并且在每个分组里面对 age 进行累加
    db.test.aggregate([
        {
            $group : {
                "_id" : "$email",
                "count" : {$sum : "$age"}            
            }
         }
    ])
    
    
    // 4. 根据 email 字段进行分组，在每个分组里面对 age 进行累加, 并且返回 count 大于 106
    // 在一些情况下也可以先 match 再分组 group
    db.test.aggregate([
        {
            $group : {
                "_id" : "$email",
                "count" : {$sum : "$age"}            
            }
         },
         {
            $match : {
                "count" : {$gt : 106}
            }
         }
    ])
    
    
    // 5. 先根据 name 为 order 开头的过滤，接着拆开 items 字段(数组)，
    // 把里面的每一项的 num 和 price 相乘赋给 total，并且把 name 字段赋给 orderId，返回结果
    db.test.aggregate([
        {
            $match : {
                "name" : /^order/
            }
        },
        { $unwind : "$items"},
        {
            $project : {
                "orderId" : "$name",
                "total" : {
                    $multiply : [
                        "$items.num", "$items.price"
                    ]
                }
            }
        }
    ])
    
    
    // 6. 过滤出非 order 开头的全部文档，找出最大的 age （可以换成 min, avg）
    db.test.aggregate([
        {
            $match : {
                "name" : /^[^order]/
            }
        },
        {
            $group : {
                "_id" : null,
                "maxAge" : {
                    $max : "$age"
                 }
            }
        }
    ])
    
    
    // 7. 根据 email 分组，以数组的形式返回每个分组内的 name 字段
    db.test.aggregate([
        {
            $group : {
                "_id" : "$email",
                "title" : {
                    $push : "$name"
                 }
            }
        }
    ])

![](https://cdn.nlark.com/yuque/0/2024/png/42911816/1719906927601-9d67dbe7-3282-4e3f-930c-d48c2ec84157.png)

https://www.cnblogs.com/jasonminghao/p/13179629.html
