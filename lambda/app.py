import os, json, boto3, base64
from urllib.parse import unquote_plus

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime", region_name=os.environ.get("AWS_REGION","us-east-1"))
MODEL_ID = os.environ.get("MODEL_ID","anthropic.claude-3-5-sonnet-20240620-v1:0")
MAX_TAGS = 10

def _read_s3_obj(bucket, key):
    obj = s3.get_object(Bucket=bucket, Key=key)
    return obj["Body"].read()

def _put_json(bucket, key, data):
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(data, indent=2).encode("utf-8"),
                  ContentType="application/json")

def _tag_object(bucket, key, tags):
    tagset = [{"Key": f"ai_{i+1}", "Value": str(t)[:128]} for i,t in enumerate(tags[:MAX_TAGS])]
    s3.put_object_tagging(Bucket=bucket, Key=key, Tagging={"TagSet": tagset})

def handler(event, _):
    for rec in event.get("Records", []):
        bucket = rec["s3"]["bucket"]["name"]
        key = unquote_plus(rec["s3"]["object"]["key"])
        if not key.lower().endswith((".jpg",".jpeg",".png",".webp")):
            continue
        img = _read_s3_obj(bucket, key)
        payload = {
            "anthropic_version":"bedrock-2023-05-31",
            "max_tokens":512,
            "messages":[{
                "role":"user",
                "content":[
                    {"type":"text","text":"Describe this image. Return strict JSON: {\"title\": str, \"caption\": str, \"tags\": [str,...]}."},
                    {"type":"image","source":{"type":"base64","media_type":"image/jpeg","data":base64.b64encode(img).decode()}}
                ]
            }]
        }
        resp = bedrock.invoke_model(modelId=MODEL_ID, body=json.dumps(payload))
        out = json.loads(resp["body"].read())
        txt = out["content"][0]["text"]
        try:
            meta = json.loads(txt)
        except Exception:
            meta = {"title":"", "caption":txt, "tags":[]}

        dirname = key.rsplit("/",1)[0] if "/" in key else ""
        meta_key = (dirname + "/metadata/" if dirname else "metadata/") + os.path.basename(key) + ".json"
        _put_json(bucket, meta_key, meta)
        if meta.get("tags"):
            _tag_object(bucket, key, meta["tags"])
    return {"ok": True}
