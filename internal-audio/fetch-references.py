"""Cache a bounded set of public source references, pinned to commit IDs."""
import hashlib
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parent / 'references'
root.mkdir(exist_ok=True)
repos = [
    ('LineageOS/android_kernel_samsung_msm8974', 'lineage-18.1', 'samsung'),
    ('KorelisLabs/lumia-1520-mainline', 'main', 'lumia'),
]
manifest = []
for repo, branch, label in repos:
    commit = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repo}/commits/{branch}']))['sha']
    tree = json.loads(subprocess.check_output(['gh', 'api', f'repos/{repo}/git/trees/{commit}?recursive=1']))
    paths = [v['path'] for v in tree['tree'] if v['type'] == 'blob']
    if label == 'samsung':
        wanted = [p for p in paths if
            (p.startswith('arch/arm/boot/dts/msm8974pro/') and
             ('audio' in p or 'sound' in p or p.endswith(('msm8974.dtsi', 'msm8974pro-ac.dtsi', 'msm8974pro-ac-sec-k-r03.dts'))))
            or p in ('Documentation/devicetree/bindings/sound/taiko_codec.txt',
                     'sound/soc/msm/msm8974.c', 'drivers/mfd/wcd9xxx-core.c')]
    else:
        wanted = [p for p in paths if p in (
            'patches/0001-slimbus-ngd-late-registration-recovery.patch',
            'patches/0002-slimbus-wcd9320-codec-core.patch',
            'patches/0003-regmap-slimbus-pass-slim_device-as-bus-context.patch',
            'patches/qcom-msm8974-microsoft-rm940.dts')]
    for path in wanted:
        target = root / label / path
        target.parent.mkdir(parents=True, exist_ok=True)
        data = subprocess.check_output(['gh', 'api', f'repos/{repo}/contents/{path}?ref={commit}',
                                        '-H', 'Accept: application/vnd.github.raw+json'])
        target.write_bytes(data)
        manifest.append({'repo': repo, 'commit': commit, 'path': path,
                         'sha256': hashlib.sha256(data).hexdigest()})
        print(label, path, len(data))
(root / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
