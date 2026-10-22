# 加载时省去一次未被使用的墙面数据填充

2026-10-23。此处只有可审查提案，不改WallBlend、不编译或部署。

准确基线为WallBlend 0.5.9-scene / 14112DA06214BCA51C6875D2527E73246DCB4C985CAADDA719EB4F77F1C0920D；生产源在`mods/ContinuousScene/build/generated/wb-motion-source`，13份源按原LF文本规则已绑定。不是WallBlend仓库当前HEAD。

拟只改`wallblend/SceneBlendCache.as`的`view`末尾：删除创建时的`refreshView(g,s,result,region);`。保留返回result、空space/backobjs、区域裁剪、原生缓冲包装、材料缓存及真正绘制前的`refreshView(g,surface,pass.view,pass.region)`。没有前置绘图消费者，删掉的是同一帧立即被第二次填充覆盖的数据；延后绘制的块仍在绘制前读取最新状态。

```diff
 var result:Object={loc:loc,frontBmp:s.nativeBuffers[0],visFront:front,visBack:back,getObj:g.getObj};
-refreshView(g,s,result,region);
 return result;
```

不实施另一个把makePasses跨帧延后的方案；不增加loc.active等待，不改接缝、材质、破坏保护、更新频率或原生可见范围。外部版本号/测试标识如需变化单独记录，不能混入其他生产改动。

证据：RConnect实测64bb6b4030的-100回调组首进2733ms、重访2505ms，但此组同时含WB和FA，不能称这些全是WB或保证能省去2.5秒。WB负责会话只读核对了未使用的首次填充，记录在`mods/WallBlend/knowledge/discoveries/scene-view-initialization-20261023.md`。重复填充是已确认代码路径，节省多少尚无证据。

若获准：只构建隔离候选，先用准确旧/新类检查初建、跨区域接线、延期后首次绘制、设置刷新、破坏及清除重建的最终像素和状态；再在原生加载中对照总耗时和恢复操作后的帧耗时。无稳定收益不合入；若出现画面差异即停止。通过原门槛后才随RConnect整合版部署，单独备份和复验。安装版在此之前不变。

权限边界：工作区其他模组默认只读；此前WB授权限定两处字符串比较。本提案是另一处初始化调用，不把旧授权扩展解释成任意WB改动。
