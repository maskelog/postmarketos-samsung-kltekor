# Galaxy S5 IR 송신기 (IR blaster)

Galaxy S5 상단의 IR LED를 메인라인 커널에서 쓸 수 있게 만든 드라이버와
그 작동 방식입니다. 커널 r16(패치 0037, 0038)부터 포함됩니다.

## 확인된 상태

- r16 부팅 시 FPGA 설정 성공, `/dev/lirc0` 생성 (raw 송신, 스캔코드 인코더, 반송파 설정 지원)
- 삼성 TV 전원 신호(Samsung32, 주소 0x07, 명령 0x02)로 **실제 TV가 켜지는 것 확인**
- 다른 버튼 코드, 다른 제조사 기기, 수신(learn) 기능은 검증하지 않음
- 검증 보드: kltekor, 다운스트림 DT 기준 r06–r08 계열(`fw_ver = 2`, pcal6416 GPIO 확장칩 있음)

## 하드웨어 구조

IR LED는 SoC가 직접 켜고 끄지 않습니다. 사이에 **Lattice iCE40 FPGA**가 있고,
FPGA가 반송파(예: 38 kHz)를 만들어 LED를 구동합니다.

```
 MSM8974 ──GPIO108/109──▶ iCE40 FPGA ──▶ IR LED (전원: PMA8084 L19 3.3 V)
   │  GPIO58 (GP2 24 MHz 클럭) ──▶ │
   │  GPIO101 ◀── ack/busy ─────── │
   │  PMA8084 GPIO11 ──▶ CRESET_B  │
   └─ 확장칩 4-0020 pin 3 ──▶ enable│
```

| 신호 | 연결 | 역할 |
| --- | --- | --- |
| scl / data clock | TLMM GPIO108 | 설정 단계: SPI 클럭, 이후: I2C SCL |
| sda / data | TLMM GPIO109 | 설정 단계: SPI 데이터, 이후: I2C SDA |
| ack | TLMM GPIO101 | 패킷 수신 확인(Low), 송신 완료(High) |
| clock | TLMM GPIO58, 기능 `gcc_gp_clk2` | FPGA 동작 클럭, GCC GP2 24 MHz |
| CRESET_B | PMA8084 GPIO11 | FPGA 설정 시작(리셋 해제) |
| enable | pcal6416(4-0020) pin 3 | 동작 중 Low (다운스트림 이름 `rst_n`) |
| LED 전원 | PMA8084 L19 3.3 V | 터치키와 공유, 부팅 후 이미 켜져 있음 |

값은 삼성 다운스트림 커널의 `drivers/misc/ice40xx.c`와
`msm8974pro-ac-sec-k-r06`~`r08` DT에서 가져왔습니다.

**주의:** CRESET_B(PMA8084 GPIO11)는 PMIC의 S4(1.8 V)를 전원으로 써야 합니다.
부팅 직후 이 핀은 VPH(배터리 전압, 약 3.7 V) 쪽 입력으로 설정돼 있으므로,
사용자 공간에서 이 핀을 그대로 High로 출력하면 FPGA에 과전압이 걸릴 수 있습니다.
0038의 DT pinctrl이 `power-source = <PMA8084_GPIO_S4>`로 먼저 바꾼 뒤 출력합니다.

## 작동 순서

### 1. 부팅 시 FPGA 설정 (한 번)

iCE40은 SRAM 방식이라 전원이 들어올 때마다 설정 파일(비트스트림)을 다시 넣어야 합니다.
드라이버 probe에서 다음 순서로 진행합니다.

1. GP2 클럭 켜기, enable 활성화
2. CRESET_B를 Low로 30–50 µs 유지한 뒤 High → FPGA가 설정 대기 상태로 들어감
3. 1 ms 대기 후 비트스트림 32,216바이트를 GPIO108(클럭)/109(데이터)로 MSB부터 한 비트씩 전송
4. 데이터 High 상태로 클럭 200번 추가 → 설정 완료
5. 두 선을 입력으로 풀어 줌. 이때부터 두 선은 FPGA의 I2C 버스(주소 0x50)
6. I2C로 8바이트를 읽어 응답 확인 (실기기 응답: `20 00 04 00 00 00 00 00`)

성공하면 커널 로그에 다음이 찍힙니다.

```
ir-ice40-samsung ir-transmitter: iCE40 IR configured, id 20 00 04 00 00 00 00 00
rc rc0: lirc_dev: driver ir_ice40_samsung registered at minor = 0, no receiver, raw IR transmitter
```

### 2. 신호 한 번 보내기

사용자 공간이 `/dev/lirc0`에 켜짐/꺼짐 길이(µs) 목록을 쓰면 드라이버가 다음을 수행합니다.

1. 각 길이를 **반송파 주기 수**로 변환: `cycles = µs × 반송파 / 1,000,000` (16비트)
2. 패킷 구성 후 I2C로 한 번에 전송

   | 바이트 | 내용 |
   | --- | --- |
   | 0 | 레지스터 주소 `0x00` |
   | 1–2 | 길이 `5 + 2 × n` (빅엔디언) |
   | 3 | 동작 `0` = 1회 송신 |
   | 4–5 | 반송파 주파수 Hz (빅엔디언) |
   | 6… | 켜짐/꺼짐 주기 수, 각 2바이트 (빅엔디언) |

3. 10 ms 뒤 ack 핀 확인: **Low면 FPGA가 체크섬을 받아들인 것**, High면 최대 5번 재전송
4. 전체 신호 길이만큼 대기한 뒤 ack 핀이 다시 **High가 되면 송신 완료**
5. LED 전원, enable, 클럭 끄기

실제 LED 깜빡임과 반송파 생성은 FPGA가 하므로, CPU 부하나 스케줄링 지연이
IR 타이밍에 영향을 주지 않습니다.

## 커널 구성 요소

| 파일 | 내용 |
| --- | --- |
| `msm8974-iommu-aport/0037-media-rc-add-the-Samsung-Galaxy-S5-iCE40-IR-transmit.patch` | `drivers/media/rc/ir-ice40-samsung.c` 드라이버 (rc-core raw TX) |
| `msm8974-iommu-aport/0038-ARM-dts-qcom-msm8974pro-samsung-klte-add-the-iCE40-I.patch` | klte DT: `ir-transmitter` 노드, 클럭, GPIO, pinctrl |
| `config-postmarketos-qcom-msm8974.armv7` | `RC_CORE=y`, `LIRC=y`, `RC_DEVICES=y`, `IR_ICE40_SAMSUNG=m` |

rc-core의 표준 LIRC 장치로 등록되므로 `ir-ctl`(v4l-utils) 같은 기존 도구를
그대로 쓸 수 있습니다. 반송파는 15–65 kHz, 기본값 38 kHz입니다.

## 설치

### FPGA 비트스트림

비트스트림은 삼성 바이너리라 이 저장소에 넣지 않았습니다.
LineageOS 커널 저장소에서 받아 변환합니다.

```sh
curl -LO https://raw.githubusercontent.com/LineageOS/android_kernel_samsung_msm8974/lineage-18.1/firmware/ice40xx/i2c_top_bitmap_2.fw.ihex
objcopy -I ihex -O binary i2c_top_bitmap_2.fw.ihex i2c_top_bitmap_2.fw
sha256sum i2c_top_bitmap_2.fw
# 60abd1aae283a84f6ac3220aed0532da6bd079034f041556247299a1f56763f6
sudo install -D -m 644 i2c_top_bitmap_2.fw /lib/firmware/ice40xx/i2c_top_bitmap_2.fw
```

파일은 드라이버가 probe될 때 필요합니다. 커널보다 먼저 넣어 두거나,
나중에 넣었다면 `sudo modprobe -r ir-ice40-samsung && sudo modprobe ir-ice40-samsung`로 다시 불러옵니다.

### 일반 사용자 권한 (선택)

`/dev/lirc0`는 기본적으로 root만 쓸 수 있습니다.
[`70-lirc.rules`](70-lirc.rules)를 `/etc/udev/rules.d/`에 넣으면 `plugdev` 그룹이 쓸 수 있습니다.

```sh
sudo install -m 644 70-lirc.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=lirc --action=add
```

## 사용 예

```sh
sudo apk add v4l-utils
ir-ctl --features                     # 송신 기능 확인
ir-ctl -s samsung-tv-power.txt        # 삼성 TV 전원 (실기기 확인)
ir-ctl -S nec:0x0408                  # 커널 내장 인코더 예: LG TV 전원 (미확인)
```

**삼성 TV는 `nec`/`necx` 인코더로는 반응하지 않을 수 있습니다.**
삼성 TV가 쓰는 Samsung32는 비트 구성이 NEC와 같지만, 시작 신호가 NEC(9 ms 켜짐, 4.5 ms 꺼짐)와
달리 4.5 ms 켜짐, 4.5 ms 꺼짐입니다. 커널 인코더에는 이 방식이 없어서
[`samsung-tv-power.txt`](samsung-tv-power.txt)처럼 파형을 직접 적어 보냅니다.

Samsung32 한 프레임은 다음과 같습니다.

- 시작: 4500 µs 켜짐, 4500 µs 꺼짐
- 데이터: 주소, 주소, 명령, 명령의 비트 반전 순으로 4바이트, 각 바이트 LSB부터
  - 비트 0: 560 µs 켜짐, 560 µs 꺼짐
  - 비트 1: 560 µs 켜짐, 1690 µs 꺼짐
- 끝: 560 µs 켜짐

다른 버튼은 명령 값만 바꾸면 됩니다. 흔히 쓰이는 값은 다음과 같으며, 전원 외에는 검증하지 않았습니다.
음량+ `0x07`, 음량− `0x0B`, 음소거 `0x0F`, 채널+ `0x12`, 채널− `0x10`, 입력 `0x01`.

## 출처

- 프로토콜, 핀, 순서: Samsung 다운스트림 `drivers/misc/ice40xx.c`, `include/linux/irda_ice40.h`
  ([LineageOS/android_kernel_samsung_msm8974](https://github.com/LineageOS/android_kernel_samsung_msm8974), lineage-18.1)
- 드라이버와 DT 패치는 이 작업에서 새로 작성했으며 커널과 같은 GPL-2.0-only입니다.
