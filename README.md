# 🎵 VGA 기반 카메라 색상 인식 리듬게임 (RHYTHM BEAT)

> 온디바이스AI 시스템 반도체 설계 1기 | 송주연 | 대한상공회의소 서울기술교육센터 | 2026.07.21

---

## 📌 프로젝트 개요 (Project Overview)
  * 카메라 센서(OV7670)를 통한 실시간 영상 입력
  * VGA 화면 구역 분할 및 **빨간색(Red) 탐지** 알고리즘 구현
  * Python을 활용한 게임 UI(상황별 화면)
  * Python(PC)와 FPGA 간 UART 통신으로 노트 및 점수 데이터 송수신
  * UVM(Universal Verification Methodology) 기반 Top_Game 모듈 검증

---

## 👥 담당 역할
- UART Receiver 설계
- <애상> 노트 ROM 제작
- ROM Reader, Note Controller 모듈 설계(진행 도중 구조 변경되어 삭제됨)
---

## 🛠 시스템 구조 및 설계 (System Architecture)

### 1. 모듈 설계
#### 전체 Block Diagram
<img width="2159" height="1519" alt="image" src="https://github.com/user-attachments/assets/563a6f8d-b1f4-4de9-b5bb-7b9da61deb12" />

#### 모듈 상세

* **Main Controller**: 게임의 전체 제어 담당(상태 제어, VGA 화면 노트 생성, 판정, 점수 계산 모듈 포함)
* **VGA cam**: 640x480 @ 60Hz VGA 제어 및 노트 생성, 판정선, 점수판(SCORE) 등의 그래픽 오버레이 처리
  1.  <img width="798" height="439" alt="image" src="https://github.com/user-attachments/assets/121df019-40fa-411c-87b4-29d87a1f8d7c" />

* **카메라 입력 & 색상 탐지 모듈 (Camera & Color Detection)**:
  * 실시간 입력 영상에서 HSV / RGB 색상 공간 변환을 통해 특정 영역 내의 **빨간색 물체** 탐지
  * 화면 구역을 나누어 각 영역에 들어온 입력 신호를 노트 판정 신호로 전환
* **VGA 컨트롤러 & 디스플레이 모듈**:
  * 640x480 @ 60Hz VGA 제어
  * 노트(Node) 생성, 판정선(Hit Line), 점수판(SCORE) 등의 그래픽 오버레이 처리
* **게임 로직 모듈 (Game Logic)**:
  * 4-Lane(A, S, D, F) 노트 낙하 로직 및 판정 알고리즘 (Perfect/Great/Miss)
  * 스코어링 시스템 구현

---

## 🧪 검증 환경 (Verification)

### UVM 기반 환경 구축 (`Top_Game UVM`)
* SystemVerilog 및 **UVM (Universal Verification Methodology)**을 활용하여 탑 모듈(`Top_Game`) 검증 환경 구축
* Random Testbench 작성 및 Scoreboard를 통한 실시간 입력 대비 VGA 출력/게임 스코어 변화의 정확성 검증

---

## 🚀 주요 기능 시연 (Features & Demo)

1. **시작 화면 (Title Screen)**
   * `RHYTHM BEAT` 메인 타이틀 및 `PRESS START` 애니메이션
2. **카메라 인식 및 구역 탐지**
   * 카메라에 **빨간색 물체**가 포착되면 지정된 구역의 입력 이벤트 발생
3. **게임 플레이 (In-Game)**
   * 위에서 아래로 떨어지는 노트에 맞춰 탐지 영역을 터치하여 스코어 획득

---

## 🔧 Trouble Shooting & 고찰

* **카메라 노이즈 및 색상 탐지 오작동 해결**
  * 조명 환경에 따른 색상 탐지 오차를 줄이기 위해 픽셀 신호에 대한 Thresholding 조건 보정 및 필터링 알고리즘 적용
* **VGA 동기화 및 렌더링 최적화**
  * 여러 개체가 동시에 움직일 때 화면 찢어짐(Tearing)을 방지하기 위해 픽셀 카운터 및 V-Sync / H-Sync 타이밍 최적화
* **UVM 검증 가품성 확인**
  * 비동기 카메라 입력과 동기식 VGA 출력 간의 타이밍 미스매치를 UVM Monitor/Scoreboard를 통해 추적 및 수정

---

## 📁 폴더 구조 (Directory Structure)

```text
├── rtl/                   # Verilog / SystemVerilog RTL 소스 코드
│   ├── vga_controller.v   # VGA 타이밍 제어
│   ├── color_detector.v   # 카메라 색상 인식 및 구역 판정
│   ├── game_logic.v       # 리듬게임 로직 및 점수 계산
│   └── top_game.v         # 최상위 탑 모듈
├── uvm/                   # UVM 검증 환경 코드
│   ├── env.sv
│   ├── test.sv
│   └── tb_top.sv
├── doc/                   # 프로젝트 발표 자료 및 이미지
└── README.md
