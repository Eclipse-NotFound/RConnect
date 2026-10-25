package lad {
    import flash.utils.getQualifiedClassName;

    /** Read-only visual classification of native 1.02 projectiles, not damage simulation. */
    public final class LadProjectileProfiles {
        public static const EMITTER_IDS:Array = [
            "expl","explw","impexpl","iceexpl","plaexpl","fireexpl",
            "balefire","baleblast","sparkleexpl","acidexpl",
            "react","ttexpl","ttplaexpl","eclipse"
        ];

        public static function bullet(b:*):Object {
            var p:Object=classify(b);
            if(!p || !p.flight) return p;
            var v:String=shortName(field(b,"vis",null)).toLowerCase().replace("visbul","");
            // World-pixel spill width, not a replacement for the native sprite.
            // Keep compact/orb silhouettes distinct from a stretched tracer.
            p.shape="bolt";p.width=62;p.length=90;p.taper=0.35;p.rear=0;
            if(p.beam) {p.shape="beam";p.width=42;p.length=2400;p.taper=1;}
            else if(v=="visualbullet" || v=="visualrainbow" || v=="rail") {
                p.shape="streak";p.width=v=="rail"?36:28;p.length=160;p.taper=0.16;
                if(p.name!="tracer" && v!="rail")p.width=34;
            } else if(v=="rocket" || v=="rocketgas") {
                p.shape="exhaust";p.width=48;p.length=110;p.taper=0.12;p.rear=12;
            } else if(contains("flame,flame2,dflame,arson",v)) {
                p.shape="flame";p.width=70;p.length=110;p.taper=0.35;
            } else if(v=="blump" || v=="plasma3" || v=="plasma3a" || v=="plasma5") {
                p.width=48;p.length=120;p.taper=0.18;
            } else if(contains("baleegg,eclipse,plasma2,plasma4,plasma6,ttplasma,ttnavod,ttmoln,ttzalp,fireball,flare,bloodpsy,defwave,psy",v)) {
                p.shape="orb";p.width=v=="eclipse" || v=="ttzalp"?86:70;p.length=45;p.taper=0.45;
            } else if(contains("lightning,spark,pulse,ttmoln,skybolt,sel",v)) {
                p.shape="arc";p.width=48;p.length=115;p.taper=0.22;
            } else if(v=="blade" || v=="blood" || v=="ice") {
                p.shape="shard";p.width=42;p.length=72;p.taper=0.18;
            }
            // Native atlas distinguishes coloured variants which share a damage code.
            if(v=="plasma2" || v=="ttplasma" || v=="flame2")p.color=0xBCEFFF;
            else if(v=="plasma5" || v=="plasma6")p.color=0xFFA4D6;
            else if(v=="ttnavod" || v=="dflame")p.color=0xB2FF9C;
            else if(v=="ttzalp")p.color=0xFFD092;
            else if(v=="laser4" || v=="mray")p.color=0xA7FFD2;
            else if(v=="laser8")p.color=0xB8FF94;
            else if(v=="laser7")p.color=0xFFA6B5;
            else if(v=="lightning" || v=="spark")p.color=0xFFF2A4;
            return p;
        }
        private static function classify(b:*):Object {
            if(b == null) return null;
            var type:String = getQualifiedClassName(b);
            if(type != "fe.weapon::Bullet" && type != "fe.weapon::SmartBullet" &&
                type != "fe.weapon::PhisBullet") return null;
            // Blast delivery bullets, melee sweeps and other invisible proxies must never emit.
            var visual:* = field(b,"vis",null);
            if(visual == null || int(field(b,"tipBullet",0)) != 0) return null;
            var v:String = shortName(visual).toLowerCase();
            if(v.indexOf("visbul") == 0) v = v.substr(6);
            var weapon:* = field(b,"weap",null);
            var id:String = String(field(weapon,"id",field(b,"weapId",""))).toLowerCase();
            var damage:int = int(field(b,"tipDamage",0));
            var spring:int = int(field(b,"spring",1));
            var p:Object;

            // Thrown canisters and launched grenade shells are unlit until detonation.
            if((type == "fe.weapon::PhisBullet" && v!="gren50") || v == "gren40" ||
                int(field(weapon,"tip",0)) == 4) {
                p = explosion(damage,String(field(weapon,"visexpl","")));
                if(p) { p.name = "grenade-" + p.name; p.flight = false; p.muzzle = false; }
                return p;
            }
            // a_expl uses grenade physics (phisbul=1), but its native gren50 art
            // is a luminous magical bolt. Ordinary thrown shells remain unlit.
            if(v=="gren50")return profile("explosive-spell",0xFFBD9D,105,0.65,0.12,230,0.4,false,true,true);

            // Coloured liquid, sharp projectiles and mechanical debris are not light sources.
            if(contains("dart,saw,spikenail,ship,venom,plevok,pinkplevok,kapl,pinkkapl,pink",v)) return null;
            if(v == "rocket" || v == "rocketgas" || v == "ttnavod") {
                p = profile("rocket",0xFFB06B,95,0.7,0.12,230,0.4,false,true,true);
                if(v == "rocketgas" || damage == 7 || damage == 19) {
                    p.name = "gas-rocket"; p.impact = 0; p.life = 0;
                }
                if(v == "ttnavod") { p.impact = 280; p.life = 0.5; }
                return p;
            }
            if(damage == 7 || damage == 10 || damage == 19) return null;

            if(v == "baleegg" || id == "bel" || damage == 15)
                return profile("balefire",0xD5FF89,105,0.65,0.14,300,0.65,false,true,true);
            if(v == "ttzalp")
                return profile("heavy-plasma",0x9EFFB6,140,0.8,0.18,280,0.5,false,true,true);
            if(v == "eclipse")
                return profile("eclipse",0xC1A0FF,150,0.8,0.2,250,0.5,false,true,true);

            // Ammo effects are applied to the live Bullet. Incendiary ammo keeps damage type 0.
            if(v == "visualbullet" || v == "visualrainbow") {
                if(damage == 6) return profile("plasma-ammo",0xA0FF9C,90,0.65,0.12,130,0.24,false,true,true);
                if(damage == 8 || damage == 9) return profile("electric-ammo",0x9DE6FF,90,0.65,0.1,135,0.2,false,true,true);
                if(damage == 3 || Number(field(weapon,"ammoFire",0)) > 0)
                    return profile("incendiary",0xFFD08B,80,0.6,0.12,110,0.2,false,true,true);
                p = profile("tracer",v == "visualrainbow" ? 0xF1CEFF : 0xFFE3AA,65,0.55,0.09,85,0.12,false,true,true);
                return p;
            }

            // 'spring' alone is insufficient: only these native visuals are actual beams.
            var beam:Boolean = spring >= 2 && (v.indexOf("laser") == 0 ||
                contains("sparkl,termo,ttlaser,mray,dray,friend",v));
            if(beam) {
                var beamColor:uint = 0xFF9A88;
                if(contains("laser1,laser3,laser8",v)) beamColor = 0xAEDCFF;
                else if(contains("laser4,mray",v)) beamColor = 0xC7B1FF;
                else if(contains("laser6,friend",v)) beamColor = 0xF1CEFF;
                else if(contains("laser7,dray",v)) beamColor = 0xB695E8;
                else if(v == "termo") beamColor = 0xFFD29B;
                else if(v == "sparkl") beamColor = 0xC3A4FF;
                return profile("beam",beamColor,110,0.8,0.12,130,0.2,true,true,true);
            }
            if(v == "rail" || id == "rail") return profile("rail",0xC6E9FF,95,0.65,0.12,125,0.18,false,true,true);
            if(v == "blump") return profile("laser-pulse",0xFFAC99,100,0.75,0.12,125,0.2,false,true,true);
            if(contains("blood,bloodlight,bloodpsy",v))
                return profile("blood-magic",0xFF9CA9,100,0.65,0.14,125,0.22,false,true,true);
            if(contains("necrbullet,necro",v) || damage == 16)
                return profile("necro",0xBCA2E8,90,0.55,0.16,120,0.25,false,true,true);
            if(v == "flame" || v == "flame2" || v == "dflame" || v == "arson" ||
                v == "flare" || v == "fireball" || int(field(b,"flame",0)) > 0 || damage == 3) {
                p = profile("fire",0xFFC078,120,0.8,0.16,170,0.35,false,true,true);
                if(v == "flare" || id == "flaregun") { p.name = "signal-flare"; p.radius = 150; p.tail = 0.22; p.life = 0.45; }
                return p;
            }
            if(v == "cryo" || v == "ice" || damage == 11)
                return profile("cryo",0xBDEFFF,105,0.65,0.14,140,0.25,false,true,true);
            if(contains("telebullet,blade,psy,mbul,defwave",v))
                return profile("magic",0xD4B5FF,100,0.65,0.14,140,0.25,false,true,true);
            if(contains("lightning,spark,pulse,ttmoln,skybolt,sel",v) || damage == 8 || damage == 9 || damage == 18)
                return profile("electric",0xA9E2FF,110,0.75,0.12,150,0.25,false,true,true);
            if(v.indexOf("plasma") == 0 || v == "ttplasma" || damage == 6)
                return profile("plasma",0xACFFA2,125,0.8,0.18,170,0.35,false,true,true);
            // Unknown ordinary visuals stay dark; explicit energy damage above
            // remains a fallback for native variants. Physical props are excluded first.
            return null;
        }

        public static function emitter(id:String):Object {
            switch(id) {
                case "expl": return flashProfile("explosion",0xFFD49A,250,0.9,0.35);
                case "explw": return flashProfile("underwater-explosion",0xBADAE8,150,0.55,0.25);
                case "fireexpl": return flashProfile("fire-explosion",0xFFC078,240,0.85,0.45);
                case "plaexpl": return flashProfile("plasma-explosion",0xACFFA2,260,0.85,0.45);
                case "impexpl": return flashProfile("emp-explosion",0xA9E2FF,240,0.85,0.3);
                case "iceexpl": return flashProfile("cryo-explosion",0xBDEFFF,220,0.7,0.35);
                case "balefire": case "baleblast": return flashProfile("balefire-explosion",0xD5FF89,320,0.95,0.65);
                case "sparkleexpl": return flashProfile("sparkle-explosion",0xE0B5FF,300,0.9,0.5);
                case "acidexpl": return flashProfile("acid-splash",0xC0E8A0,90,0.3,0.12);
                case "react": return flashProfile("incendiary-burst",0xFFC078,135,0.75,0.25);
                case "ttexpl": return flashProfile("heavy-explosion",0xFFD49A,300,0.95,0.45);
                case "ttplaexpl": return flashProfile("heavy-plasma-explosion",0xACFFA2,300,0.9,0.5);
                case "eclipse": return flashProfile("eclipse-explosion",0xC1A0FF,260,0.85,0.5);
            }
            return null;
        }

        private static function explosion(damage:int,overrideId:String):Object {
            if(overrideId == "sparkle") overrideId = "sparkleexpl";
            var p:Object = emitter(overrideId);
            if(p) return p;
            switch(damage) {
                case 7: case 19: return null;
                case 3: return emitter("fireexpl");
                case 6: return emitter("plaexpl");
                case 8: return emitter("impexpl");
                case 10: return emitter("acidexpl");
                case 11: return emitter("iceexpl");
                case 15: return emitter("balefire");
            }
            return emitter("expl");
        }
        private static function flashProfile(name:String,color:uint,radius:Number,power:Number,life:Number):Object {
            return profile(name,color,radius,power,0,radius,life,false,false,false);
        }
        private static function profile(name:String,color:uint,radius:Number,power:Number,tail:Number,
            impact:Number,life:Number,beam:Boolean,muzzle:Boolean,flight:Boolean):Object {
            return {name:name,color:color,radius:radius,power:power,tail:tail,impact:impact,life:life,
                beam:beam,muzzle:muzzle,flight:flight};
        }
        private static function contains(list:String,value:String):Boolean { return (","+list+",").indexOf(","+value+",") >= 0; }
        private static function shortName(value:*):String {
            var name:String = getQualifiedClassName(value);
            var index:int = name.lastIndexOf("::");
            return index < 0 ? name : name.substr(index+2);
        }
        private static function field(value:*,name:String,fallback:*):* {
            if(value == null) return fallback;
            try { var result:* = value[name]; if(result !== undefined && result !== null) return result; } catch(error:*) { }
            return fallback;
        }
    }
}
