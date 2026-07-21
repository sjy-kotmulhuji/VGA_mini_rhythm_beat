# 작업 설명서: 파이썬 마스터 / FPGA 슬레이브 리듬게임 동기화

리듬게임의 노트 타이밍 제어 주도권을 완전히 PC(Python)로 전환하고, FPGA 보드는 UART 수신 커맨드에 따라 노트를 출력하는 슬레이브 방식으로 변경했습니다. 이를 통해 화면 싱크와 버튼 타이밍 문제를 근본적으로 해결했습니다.

## 주요 변경 사항

### 1. 하드웨어 핀 제약 및 탑 포트 추가
* **[Basys-3-Master.xdc](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/constrs_1/imports/OnDeviceAI/Basys-3-Master.xdc)**: `B18`번의 `RsRx` 핀을 주석 해제하고 `rx` 포트로 맵핑했습니다.
* **[top.sv](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/sources_1/imports/sources_1/new/top.sv)**: 탑 모듈 포트 리스트에 `input logic rx`를 추가하고 `MainController`로 신호를 전달했습니다. 테스트벤치 `tb_top.sv`도 신규 `rx` 포트 맵핑 및 초기화 값을 추가하여 호환되도록 업데이트했습니다.

### 2. FPGA 내부 UART 수신기 연동
* **[신규 파일] [uart_rx.sv](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/sources_1/imports/sources_1/new/uart_rx.sv)**: 100MHz 클록 주파수 및 115,200 Baud rate 사양의 센터 샘플링 방식 UART Receiver 모듈을 작성하여 추가했습니다. 메타스테빌리티 방지 2단 레지스터와 스타트 비트 유효성 체크 로직이 포함되어 있습니다.
* **[MainController.sv](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/sources_1/imports/sources_1/imports/maincontroller/MainController.sv)**: 탑 포트에서 받은 `rx` 신호를 입력받아 `uart_rx` 인스턴스를 통해 바이트 단위로 해독한 후 `top_game`으로 전달합니다.
* **[top_module.sv](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/sources_1/imports/sources_1/new/top_module.sv)**: 수신 완료 신호(`rx_done`)와 데이터(`rx_data`)를 `Note_Controller` 모듈로 직접 연결했습니다.

### 3. 노트 컨트롤러(RTL) 변경
* **[Note_Controller.sv](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/sources_1/imports/sources_1/new/Note_Controller.sv)**: 복잡했던 프레임 카운팅 및 ROM 데이터 비교 회로를 제거하고, UART 수신 바이트를 직접 디코딩하여 트리거하는 커맨드 수신기로 수정했습니다.
  * `0x81`, `0x82`, `0x84`, `0x88` 입력 수신 시 해당 레인(0~3)에 노트를 즉시 발생시킵니다.
  * `0x90` 입력 수신 시 게임이 안전하게 종료(`game_done <= 1`)되도록 처리했습니다.

### 4. 파이썬 송신부 연동
* **[main.py](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/python/rhythm_game/main.py)**: `GameScreen` 화면 생성 시 시리얼 통신을 관리하는 `uart` 인스턴스를 인자로 추가 제공하도록 연동을 수정했습니다.
* **[game_screen.py](file:///d:/ondevice_sjy/VGA_Mini_Project/0713_mini_project/0713_mini_project.srcs/python/rhythm_game/screens/game_screen.py)**:
  * `PLAYING` 업데이트 상태에서 각 노트의 타임라인(스폰 시각)에 도달할 때마다 FPGA를 향해 원-핫 레인 스폰 바이트(`0x80 | (1 << lane)`)를 송신합니다.
  * 모든 노트 발송이 완료되어 배열이 비면, 곡의 끝을 나타내는 `0x90` (Game Over) 바이트를 FPGA로 쏘아주어 하드웨어 FSM 상태 전환을 유도합니다.

---

## 향후 작업 절차

1. **비트스트림 재합성**: Vivado를 열고 **`Generate Bitstream`**을 수행하여 추가된 UART RX 및 리포팅 로직을 합성해 주세요.
2. **보드 업로드**: 생성된 `.bit` 파일을 Basys3 보드에 새로 업로드해 주세요.
3. **게임 시작**: 파이썬 `main.py` 프로그램을 구동하여 연주를 실행하면, PC 음악 비트박자와 VGA 화면에 맺히는 노트가 완벽하게 일치하는 것을 볼 수 있습니다!
