"""Reuse the exact lifecycle compiler; only the input directory and fixture kind change."""
from pathlib import Path
from native_inputs import sha,once,OLD
source=OLD/'prepare.py'
assert sha(source)=='accc48963c0fb9aefd837c0044f504384c0ddf18d4cf83ca21223d93788fc062'
text=once(source.read_text(encoding='utf-8-sig'),
    "TRAVEL=ROOT/'experimental/recovery-early-sandy-native'","TRAVEL=HERE")
assert text.count("'sandy-hold-native-lifecycle-driver'")==2
text=text.replace("'sandy-hold-native-lifecycle-driver'","'sandy-hold-native-cooldown-driver'",2)
text=once(text,"if __name__=='__main__':main()",'')
exec(compile(text,str(source),'exec'),globals())
if __name__=='__main__':main()
