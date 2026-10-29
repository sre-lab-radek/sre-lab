import json
import subprocess

out = json.loads(subprocess.check_output(["terraform", "output", "-json"], cwd=".."))

web_pub = out["web_public_ips"]["value"]
web_priv = out["web_private_ips"]["value"]

lines = ["[web]"]
for name in sorted(web_pub):
    lines.append(f"{name} ansible_host={web_pub[name]} private_ip={web_priv[name]}")

lines += [
    "",
    "[mon]",
    f"mon1 ansible_host={out['mon_public_ip']['value']}",
    "",
    "[all:vars]",
    f"alb_dns={out['alb_dns']['value']}",
]

print("\n".join(lines))
