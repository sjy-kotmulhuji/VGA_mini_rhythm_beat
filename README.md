# 🎵 VGA 기반 카메라 색상 인식 리듬게임 (RHYTHM BEAT)

> **카메라 화면 영역 분할 및 특정 색상(빨간색) 물체 탐지를 통한 FPGA/VGA 인터랙티브 리듬게임 프로젝트**

---

## 📌 프로젝트 개요 (Project Overview)
* **프로젝트명**: VGA를 활용한 카메라 기반 색상 인식 리듬게임 (RHYTHM BEAT)
* **개발 기간**: 2026년
* **주요 기능**:
  * OV7670 등 카메라 센서를 통한 실시간 영상 입력 받기
  * 카메라 화면 구역 분할 및 **빨간색(Red) 물체/손바닥 탐지** 알고리즘 구현
  * VGA 모니터를 통한 4-Lane(A, S, D, F) 노트 낙하 및 게임 UI/점수 표시 (RHYTHM BEAT)
  * UVM(Universal Verification Methodology) 기반의 시스템 검증 환경 구축

---

## 👥 팀원 및 역할 (Team & Roles)

| 이름 | 역할 | 담당 업무 |
| :---: | :---: | :--- |
| **김수빈** | 팀원 | - |
| **김지홍** | 팀원 | - |
| **문태성** | 팀원 | - |
| **서어진** | 팀원 | - |
| **송주연** | 팀원 | - |
| **윤수민** | 팀원 | - |
| **조준호** | 팀원 | - |

---

## 🛠 시스템 구조 및 설계 (System Architecture)

### 1. Block Diagram & 주요 설계
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
