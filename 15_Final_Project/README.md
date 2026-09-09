# Smart Parking Lot 🚗

## 1. 프로젝트 개요
- 팀명: Cars대라
- 수행 기간: 2026.07.22 ~ 08.20
- 수행 내용: 차량 번호판 인식, 차량 맞춤 빈 자리 안내, 주차 요금 자동 정산. 스마트 무인 주차장 시스템 개발
- 사용 기술: `SystemVerilog` `C` `Python` `MicroBlaze` `UVM` `Zybo Z7-20` `ESP32` `Jetson Orin Nano`
- 담당 역할: PreProcess(SR04, SG90, VGA, UART, Wi-Fi) RTL Design & VGA UVM Verification
- 역할 분장:

| 김수빈 | 김지홍 | 문태성 | 서어진 | 송주연 | 윤수민 | 조준호 |
|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|:-----:|
| zybo 통합, SR04 Controller 설계, PCAM 스트리밍 | CNN 통합, CNN Control Unit & Conv3 & FC1 & FC2 설계 및 검증 | CNN Ref. model 설계, Conv1 & Conv2 검증 | Wi-Fi 수신 설계, 차량 추적 모델 학습, 차량 안내 서비스, 주차장 내부 관리 총괄 | Pooling Layer 설계, Conv & Pool 통합 | PreProcess 통합, SG90 Controller & VGA 설계, UART & Wi-Fi 송신 설계, VGA_top UVM 검증 | Conv1 & Conv2 설계, AI Dataset Labeling |

<br>

## 2. 주요 설계 내용
### 1) PCAM 이미지 처리 모듈 설계
<table style="width: 100%; border: none; border-collapse: collapse; margin-bottom: 20px;">
  <tr>
    <td style="text-align: center; border: none;">
      <img width="700" alt="PreProcess" src="https://github.com/user-attachments/assets/43aaea57-4f25-48f6-b93f-6de148b5395f" style="max-width: 100%; height: auto;" />
    </td>
  </tr>
  <tr>
    <td style="text-align: center; border: none; padding-top: 5px;">
      <b>그림 1-1:</b> PreProcess Block Diagram
    </td>
  </tr>
</table>

<table style="width: 100%; border: none; border-collapse: collapse; margin-bottom: 20px;">
  <tr>
    <td style="text-align: center; border: none;">
      <img width="700" alt="VGA_top" src="https://github.com/user-attachments/assets/42b4a1be-12b3-4718-9bf0-00e0d19a7768" style="max-width: 100%; height: auto;" />
    </td>
  </tr>
  <tr>
    <td style="text-align: center; border: none; padding-top: 5px;">
      <b>그림 1-2:</b> VGA_top Block Diagram
    </td>
  </tr>
</table>

<table style="width: 100%; border: none; border-collapse: collapse;">
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="FrameCrop" src="https://github.com/user-attachments/assets/a162fbb3-5f29-4eb7-9f96-6c3f213922a9" />
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="PixelBuffer" src="https://github.com/user-attachments/assets/a4716e1b-79bd-4b05-90e8-4957e0e3039d" />
    </td>
  </tr>
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 1-3:</b> VGA_top>FrameCrop Crop Region
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 1-4:</b> VGA_top>PixelBuffer Memory Map
    </td>
  </tr>
</table>

SR04 Controller에서 vga_start 신호가 들어오면 Pcam의 스트림 영상을 1 frame 캡쳐하고 가공하는 모듈. <br>
1. **FrameCrop**: 화면 중앙의 특정 영역만큼 이미지를 잘라낸 후 1/4 down scale. <br>
                  원하는 좌표일 때에만 Valid 신호가 1이 되도록 함.
2. **FrameMono**: RGB888 형식의 Pixel Data를 Binary 형식으로 변환. <br>
                  24-bit Pixel Data를 Gray Scale로 변환한 후, 임계값 이상이면 1, 이하이면 0으로 변환.
3. **FrameRegister**: Binary Pixel Data가 28-bit 모이면 PixelBuffer의 알맞은 주소에 저장. <br>
                      28-bit가 모이면 MSB와 LSB에 각각 00을 padding하여 32-bit의 word data를 PixelBuffer에 저장. <br>
                      pos 변수를 두어 word를 저장할 때마다 1씩 증가시킴으로써 4자리 숫자 이미지를 자릿수별로 저장함. <br>
<br>

### 2) PCAM 이미지 처리 모듈 UVM 검증
<table style="width: 100%; border: none; border-collapse: collapse;">
<tr>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="UVM Structure" src="https://github.com/user-attachments/assets/edc33fc6-a4fd-4adb-8255-ae703797ace3" />
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="UVM Result" src="https://github.com/user-attachments/assets/bb68d710-b043-4849-8d84-cee076a09cab" />
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="UVM Coverage" src="https://github.com/user-attachments/assets/300283e4-6fe5-41c2-b98d-99e52d5a9e3d" />
    </td>
  </tr>
<tr>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <b>그림 2-1:</b> VGA_top UVM Structure
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <b>그림 2-2:</b> VGA_top UVM Result
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <b>그림 2-3:</b> VGA_top UVM Coverage
    </td>
  </tr>
</table>

VGA_top의 데이터 무결성 검증. <br>
1080*720 RGB888 이미지를 입력으로 넣었을 때, <br>
(1) FrameRegister의 o_data가 이론 값과 일치하는지 검증. -> PASS <br>
(2) PixelBuffer에 저장된 이미지 데이터를 출력하여 의도한 결과대로 저장되었는지 확인. -> PASS <br>
<br>

### 3) SG90(서보모터) Controller 설계
<table style="width: 100%; border: none; border-collapse: collapse;">
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="SG90_Controller_BD" src="https://github.com/user-attachments/assets/c96d920d-e450-471c-915a-70737066dd82" />
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="SG90_Controller_FSM" src="https://github.com/user-attachments/assets/218cb70e-1045-4cfc-95c9-a56ce5a77ffa" />
    </td>
  </tr>
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 3-1:</b> SG90_Controller Block Diagram
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 3-2:</b> SG90_Controller FSM Chart
    </td>
</tr>
  <tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="SG90_Controller_LA0" src="https://github.com/user-attachments/assets/5aedd23f-dd46-47b4-b84b-f48af3b96b18" />
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="SG90_Controller_LA1" src="https://github.com/user-attachments/assets/96bdec41-747f-4a8b-8972-b1695cc52ef6" />
    </td>
  </tr>
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 3-3:</b> SG90_Controller pwm output(OPEN)
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 3-4:</b> SG90_Controller pwm output(CLOSE)
    </td>
  </tr>
</table>

20ms의 주기를 갖는 PWM 신호의 Duty Cycle을 변경시켜 모터의 각도를 조절함. <br>
1. **Close(0도, 차단바 닫힘)**: 0.5ms 동안 HIGH를 유지하고, 19.5ms동안 LOW를 유지.
2. **Open(90도, 차단바 열림)**: 1.5ms 동안 HIGH를 유지하고, 18.5ms동안 LOW를 유지.
<br>

### 4) UART 설계
<table style="width: 100%; border: none; border-collapse: collapse;">
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="UART_top" src="https://github.com/user-attachments/assets/1fb1f2fb-10d4-4290-b04f-81da50420086" />
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="UART_LA" src="https://github.com/user-attachments/assets/cc7a3eac-10c2-440d-beee-fb566f730eb1" />
    </td>
  </tr>
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 4-1:</b> UART_top Block Diagram
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 4-2:</b> UART Logic Analyzer
    </td>
  </tr>
</table>

CNN 모듈에서 추론한 4자리 숫자를 16-bit 입력으로 넣어주면, 8-bit씩 분리하여 TX로 2회 송신하는 모듈. <br>
1. **InfDataController**: 16-bit 입력을 8-bit 출력 두 번으로 분리하여 FIFO에 넣음.
2. **FIFO**: bit width 8 / depth 4
3. **UART_TX**: 8-bit씩 tx로 전송.

<br>

## 3. 문제 해결
### 1) Negative Slack 해결
<table style="width: 100%; border: none; border-collapse: collapse;">
<tr>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="test image" src="https://github.com/user-attachments/assets/717cd67b-69d6-4e5e-ad27-9b476571b518" />
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="error" src="https://github.com/user-attachments/assets/0f903d1f-9262-4c55-bb0f-b9acc0b51748" />
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="fixed" src="https://github.com/user-attachments/assets/2dcf1be2-7813-4fb4-853d-fc4100741ab8" />
    </td>
  </tr>
<tr>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <b>그림 5-1:</b> test image
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <b>그림 5-2:</b> PixelBuffer data (error)
    </td>
    <td style="width: 33%; text-align: center; padding: 5px; border: none;">
      <b>그림 5-3:</b> PixelBuffer data (fixed)
    </td>
  </tr>
</table>

- **문제**: 보드에 올린 후 동작시켰을 때 PixelBuffer에 비정상 값이 저장되어 있는 문제
- **해결**: Pixel Data를 처리하는 과정 전반(FrameCrop, FrameMono, FrameRegister)을 모두 한 클럭의 조합회로로 연산했기 때문에 Negative Slack이 발생한 것으로 분석. FrameCrop에서 한 클럭을 끊어주어 클럭 당 연산량을 줄임.
- **결과**: PixelBuffer에 정상적으로 이미지 데이터가 저장되는 것을 확인.
- **배운점**: 시뮬레이션에서는 정상적으로 동작하더라도, 실제 보드 환경에서는 여러 가지 원인으로 인해 정상 동작하지 않을 수 있으며, 클럭 타이밍도 중요한 디버깅 요소라는 점을 배웠다. <br>
<br>

### 2) 이미지 처리 모듈 빛 저항성 개선
<table style="width: 100%; border: none; border-collapse: collapse;">
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="PCAM light0" src="https://github.com/user-attachments/assets/be64895d-5ed0-484d-b769-1b4db91defcf" />
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="PCAM light1" src="https://github.com/user-attachments/assets/b6f7a77b-3d1a-47a9-96e0-5c6267fea6b4" />
    </td>
  </tr>
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 6-1:</b> Before
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 6-2:</b> After
    </td>
  </tr>
</table>

- **문제**: PixelBuffer에 저장된 이미지 데이터에서 번호판 영역의 글자가 흐릿하게 나타나는 문제
- **해결**: FrameMono 모듈에서 Gray Scale로 변환했을 때 RGB 값이 8'b0111_1111 이상이면 binary 1로 변환하도록 임계값을 설정했었는데, 빛의 영향을 받아 번호판이 밝게 촬영된 것이 원인이 되어 검은색 글자의 영역도 흰색으로 변환해버린 것이 원인인 것으로 분석. 임계값을 8'b1100_0000으로 높였음.
- **결과**: PixelBuffer에 자장저자된 이미지 데이터에서 번호판 영역의 글자가 선명하게 나타나는 것을 확인.
- **배운점**: Pixel Data를 받아서 처리하는 모듈을 설계하고, 처리 결과를 보며 디버깅하는 과정에서 Pixel Data를 다루는 것에 능숙해졌다. Display의 RGB 값은 실제 눈에 보이는 것보다 빛에 더욱 민감하다는 것을 알게 되었다.

<br>

## 4. 프로젝트 결과물
### 시연 환경 세팅
<table style="width: 100%; border: none; border-collapse: collapse;">
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="Parking Lot Outside" src="https://github.com/user-attachments/assets/85dca4d8-54e5-448f-be52-fc020feede42" />
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <img width="100%" alt="Parking Lot Inside" src="https://github.com/user-attachments/assets/5958b4d7-6d56-4f3e-abd0-185327b45f5f" />
    </td>
  </tr>
<tr>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 7-1:</b> 주차장 출입구
    </td>
    <td style="width: 50%; text-align: center; padding: 5px; border: none;">
      <b>그림 7-2:</b> 주차장 내부
    </td>
  </tr>
</table>
<br>

### 시연 영상 1) 주차장 출입구
https://github.com/user-attachments/assets/289033a9-31be-4239-a429-f5dad23fa527
1. 차단바의 초음파센서(SR04)에 차량이 다가가면 번호판 영역을 캡쳐하여 CNN으로 4자리 차량 번호를 추론
2. 추론이 끝나면 차단바의 서보모터(SG90)가 열림
3. 차량이 주차장 내부로 들어가면 차단바의 서보모터(SG90)가 닫힘
<br>

### 시연 영상 2) 주차장 내부 - 주차
https://github.com/user-attachments/assets/8bbab9db-809f-4355-a81b-fd2f9adebae3

1. 출입구로부터 차량 번호를 Wi-Fi로 수신받으면 최단거리 빈자리를 자동 매칭
2. 차량이 빈자리에 주차 완료할 때까지 실시간 길 안내
<br>

### 시연 영상 3) 주차장 내부 - 출차
https://github.com/user-attachments/assets/39f5116a-98db-4da4-947d-755414d094ac

1. 출구에서 차량 번호를 인식하면 체류 시간을 자동 계산하여 주차 요금 자동 정산

<br>

---
## Note. Directory Map

```text
Project/
├── 0_TEAM/
│   ├── System_Integration/
│   ├── cctv_gui/
│   └── python_code/
├── SG90/
│   ├── src/
│   │   ├── test/
│   │   │   └── SG90_test.sv
│   │   └── SG90_Controller.sv
│   └── xdc/
│       └── SG90test.xdc
├── SR04/
│   ├── src/
│   │   ├── sr04.sv
│   │   ├── SR04_Controller.sv
│   │   └── SR04_testTOP.sv
│   └── tb/
│       └── tb_SR04_testTOP.sv
├── UART/
│   ├── src/
│   │   ├── test/
│   │   │   ├── btn_debounce.v
│   │   │   └── UART_test.sv
│   │   ├── fifo.sv
│   │   ├── InfDataController.sv
│   │   ├── UART_top.sv
│   │   └── uart_tx.sv
│   ├── src/
│   │   ├── tb_uart.sv
│   │   └── tb_uart_behav.wcfg
│   └── xdc/
│       └── UARTtest.xdc
├── VGA/
│   ├── RGB1-bit_test/
│   │   ├── src/
│   │   │   ├── ip/
│   │   │   ├── frameBuffer.sv
│   │   │   ├── FrameManager.sv
│   │   │   ├── FrameManager2.sv
│   │   │   ├── i2c_master.sv
│   │   │   ├── OV7670MemController.sv
│   │   │   ├── OV7670setting.mem
│   │   │   ├── SCCB_Controller.sv
│   │   │   ├── SCCB_sender.sv
│   │   │   ├── VGA_Decoder.sv
│   │   │   └── VGAtest_top.sv
│   │   └── xdc/
│   │       └── Basys-3-Master_CAM0.xdc
│   ├── UVM/
│   │   ├── rtl/
│   │   │   ├── FrameController.sv
│   │   │   ├── PixelBuffer.sv
│   │   │   └── VGA_top.sv
│   │   ├── tb/
│   │   │   ├── tb_vga.sv
│   │   │   ├── testImage.JPG
│   │   │   ├── testImage2.jpg
│   │   │   ├── testImage2_UVM.mem
│   │   │   ├── testImage3.jpg
│   │   │   ├── testImage3_UVM.mem
│   │   │   ├── testImage_UVM.mem
│   │   │   ├── uvm_component.sv
│   │   │   ├── vga_agent.sv
│   │   │   ├── vga_coverage.sv
│   │   │   ├── vga_driver.sv
│   │   │   ├── vga_env.sv
│   │   │   ├── vga_interface.sv
│   │   │   ├── vga_monitor.sv
│   │   │   ├── vga_scoreboard.sv
│   │   │   ├── vga_seq_item.sv
│   │   │   ├── vga_sequence.sv
│   │   │   └── vga_test.sv
│   │   ├── Makefile
│   │   ├── filelist.f
│   │   ├── simv_log.tar
│   │   ├── simv_random.log
│   │   └── simv_random_coverage.log
│   ├── src/
│   │   ├── FrameController.sv
│   │   ├── PixelBuffer.sv
│   │   └── VGA_top.sv
│   └── tb/
│       ├── tb_VGA_top.sv
│       ├── tb_VGA_top_behav.wcfg
│       └── testImage.mem
├── Wi-Fi/
│   ├── src/
│   │   ├── WiFi/
│   │   │   └── WiFi.ino
│   │   └── WiFi.c
│   └── test/
│       ├── Basys-3-Master_WiFi.xdc
│       ├── btn_debounce.v
│       └── Wi-Fi_UART_top.sv
├── test/
│   ├── FrameDataController.sv
│   ├── PL_top.sv
│   ├── PL_top_TestManual.md
│   ├── UART_test_top.sv
│   ├── Zybo-Z7.xdc
│   └── btn_debounce.v
├── PreProcess.sv
├── SYNC_2FF.sv
└── README.md
```
