# postmarketOS Samsung Galaxy S5 (kltekor)

Samsung Galaxy S5의 postmarketOS 커널 패치, 설정, 문제 해결 기록입니다.
이 저장소 이름은 `kltekor`이며, 현재 패치와 UCM은 실기기에서 사용한
upstream `samsung-klte` / MSM8974 구성을 기반으로 합니다.
다른 보드 리비전이나 Galaxy S5 변형에서의 동작은 검증하지 않았습니다.

## 확인된 상태

- Linux 6.16.12 r16, 커널 빌드 #17
- 내장 스피커와 3.5 mm 이어폰 재생
- WCD9320 MBHC 기반 이어폰 삽입·제거 감지
- 삽입 시 이어폰, 제거 시 스피커 자동 전환
- 재부팅 후 출력 정상 동작: 사용자 확인
- IOMMU와 Krait CPU 주파수 관련 패치 및 실험 기록 포함
- IR 송신기(IR blaster): `/dev/lirc0`, 삼성 TV 전원 켜기 실기기 확인 → [ir-remote/README.md](ir-remote/README.md)
- 장시간 사용 시 Phosh가 죽던 문제 수정: SLIMbus NGD의 DMA 버퍼 누수로 vmalloc 영역이 약 1.5시간 만에 고갈되던 현상 (패치 0036, [phosh-death/NOTES.md](phosh-death/NOTES.md))

마이크, 헤드셋 버튼, 통화 라우팅은 검증되지 않았습니다.
오디오 상세 기록은 [internal-audio/NOTES.md](internal-audio/NOTES.md)에 있습니다.
기존 README와 HANDOFF는 작업 당시 기록이므로 최신 상태는 이 문서와
NOTES의 마지막 기록을 기준으로 확인하세요.

## 구성

| 경로 | 내용 |
| --- | --- |
| `msm8974-iommu-aport/` | APKBUILD, 커널 설정, 패치 0001–0038 |
| `kernel-pkgs/` | 실기기에서 사용한 r16 APK와 SHA-256 |
| `ir-remote/` | IR 송신기 작동 방식, udev 규칙, 삼성 TV 신호 예제 |
| `phosh-death/` | 장시간 사용 시 세션 종료 원인 분석 |
| `internal-audio/ucm2/` | 최신 ALSA UCM 설정 |
| `internal-audio/klte-jack-routing.sh` | 로그인 시 잭 자동 전환 복구 |
| `gpu-lockup/`, `krait-research-*/` | 조사 및 실험 자료 |
| 루트의 스크립트 | 기기 진단, 커널 설치, 기존 사용자 환경 수정 |

진단 로그, 개인 SSH 호스트 키, 인증 정보, Python 의존성 캐시,
다운로드한 참고 소스와 과거 커널 바이너리는 포함하지 않았습니다.
이들을 가리키는 과거 문서의 경로는 로컬 작업 환경에만 존재합니다.
진단 스크립트에는 실험 당시 설정을 바꾸는 스크립트도 있으므로 실행 전 내용을 확인하세요.

## 빌드

`pmbootstrap`을 초기화하고 해당 기기의 pmaports 환경을 준비한 뒤,
`msm8974-iommu-aport/`의 APKBUILD, 설정, 패치들을 해당
`linux-postmarketos-qcom-msm8974` aport 디렉터리에 복사합니다.

```sh
pmbootstrap build linux-postmarketos-qcom-msm8974
```

기반 소스와 체크섬은 APKBUILD에 기록돼 있습니다. 커널 소스 전체는
APKBUILD가 지정한 upstream에서 다운로드합니다.
저장소 업로드 과정에서 커널을 새로 빌드하지는 않았습니다.

## 현재 오디오 설정 설치

이 저장소를 휴대폰에 복사한 뒤, 일반 로그인 사용자로 저장소 루트에서 실행합니다.
기존 파일이 있다면 먼저 백업하세요. 아래 명령은 최신 UCM 파일을 설치합니다.
과거 `ucm-install.sh` / `ucm-update.sh`는 실험 당시 스냅샷입니다.

```sh
sudo mkdir -p /usr/share/alsa/ucm2/Samsung/klte /usr/share/alsa/ucm2/conf.d/msm8974
sudo cp internal-audio/ucm2/Samsung/klte/*.conf /usr/share/alsa/ucm2/Samsung/klte/
sudo ln -sf ../../Samsung/klte/klte.conf '/usr/share/alsa/ucm2/conf.d/msm8974/Samsung Galaxy S5.conf'
mkdir -p "$HOME/.local/bin" "$HOME/.config/autostart"
install -m 755 internal-audio/klte-jack-routing.sh "$HOME/.local/bin/klte-jack-routing"
sed "s|^Exec=.*|Exec=$HOME/.local/bin/klte-jack-routing|" \
  internal-audio/klte-jack-routing.desktop > "$HOME/.config/autostart/klte-jack-routing.desktop"
```

다음 로그인 또는 재부팅부터 적용됩니다. `gdbus`, `pactl`, `callaudiod`와
Phosh/GNOME 세션을 사용한 환경에서 확인했습니다.

`callaudiod`가 시작할 때 `module-switch-on-port-available`을 해제하므로,
시작 스크립트는 callaudiod를 활성화한 뒤 30초 동안 5초마다 누락된 모듈을
복구하고 종료합니다. 계속 실행되는 감시 서비스가 아니므로 세션 도중
callaudiod를 다시 시작하면 스크립트를 다시 실행해야 할 수 있습니다.

## 진단

```sh
amixer -c0 cget iface=CARD,name='Headphone Jack'
pactl list short modules | grep switch
pactl list cards | grep 'Active Profile'
```

이어폰을 연결하면 `on` / `HiFi (Headphones)`, 빼면 `off` /
`HiFi (Speaker)`가 확인돼야 합니다.
PC의 Python SSH 도구는 `paramiko` 설치가 필요하며, 기존 기기 주소와 계정을
사용하므로 자신의 환경에 맞게 수정해야 합니다. 비밀번호는 저장소에 없습니다.

## 출처 및 라이선스

커널 기반은 [msm8974-mainline/linux](https://github.com/msm8974-mainline/linux)이며
APKBUILD는 `GPL-2.0-only`를 명시합니다. 개별 패치의 저작권·작성자·라이선스 표기를
유지했습니다. WCD9320 포트 및 참고 구현의 출처는
[오디오 기록](internal-audio/README.md)에 정리돼 있습니다.
이 저장소의 전체 파일에 단일 라이선스를 새로 부여하지 않습니다.
