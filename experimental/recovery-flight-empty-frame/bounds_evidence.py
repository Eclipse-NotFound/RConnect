"""Independent offline viewport proof. Does not filter or rewrite trace rows."""
import math


def number(obj, key):
    value = obj.get(key) if isinstance(obj, dict) else None
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def valid_screen(screen):
    return all(number(screen, key) for key in ("x", "y", "w", "h")) and screen["w"] >= 0 and screen["h"] >= 0


def empty(screen):
    return valid_screen(screen) and (screen["w"] == 0 or screen["h"] == 0)


def valid_point(point):
    if not all(number(point, key) for key in ("x", "y", "f")):
        return False
    if not 1 <= point["f"] <= 2147483647 or not float(point["f"]).is_integer() or not valid_screen(point.get("screen")):
        return False
    if type(point.get("viewport")) is not bool:
        return False
    is_empty = empty(point["screen"])
    if is_empty and point["viewport"]:
        return False
    for key, expected in (("emptyBounds", is_empty), ("outsideViewport", not is_empty and not point["viewport"])):
        if key in point and (type(point[key]) is not bool or point[key] != expected):
            return False
    return True


def same_empty(a, b):
    return valid_point(b) and empty(b["screen"]) and all(a[key] == b[key] for key in ("f", "x", "y")) \
        and all(a["screen"][key] == b["screen"][key] for key in ("x", "y", "w", "h"))


def evaluate(source, remote):
    result = dict(emptySamples=0, matchedNativeEmpty=0, unprovenNativeEmpty=0,
                  outsideViewport=0, invalidBounds=0, proofs=[])
    for i, row in enumerate(remote):
        for j, point in enumerate(row["clips"]):
            if not valid_point(point):
                result["invalidBounds"] += 1
                continue
            if not empty(point["screen"]):
                result["outsideViewport"] += not point["viewport"]
                continue
            result["emptySamples"] += 1
            proof = None
            for k, native_row in enumerate(source):
                native = native_row.get("native")
                if not number(native, "x") or not number(native, "y") or type(native.get("ended")) is not bool:
                    continue
                for n, native_point in enumerate(native_row["clips"]):
                    if same_empty(point, native_point):
                        proof = dict(remoteRow=i, remoteClip=j, sourceRow=k, sourceClip=n,
                                     f=point["f"], x=point["x"], y=point["y"],
                                     remoteFrame=row["frame"], sourceFrame=native_row["frame"],
                                     screen=dict(point["screen"]))
                        break
                if proof is not None:
                    break
            if proof is None:
                result["unprovenNativeEmpty"] += 1
            else:
                result["matchedNativeEmpty"] += 1
                result["proofs"].append(proof)
    result["passed"] = result["outsideViewport"] == result["unprovenNativeEmpty"] == result["invalidBounds"] == 0
    return result
