# 🎵 VGA 기반 카메라 색상 인식 리듬게임 (RHYTHM BEAT)

> 온디바이스AI 시스템 반도체 설계 1기  | 대한상공회의소 서울기술교육센터 | 2026.07.21 |
> Team3(김수빈, 김지홍, 문태성, 서어진, 송주연, 윤수민, 조준호)

---

## 프로젝트 개요 (Project Overview)
  * 카메라 센서(OV7670)를 통한 **실시간 영상 입력**
  * VGA 화면 구역 분할 및 **빨간색(Red) 탐지 알고리즘** 구현
  * Python을 활용한 게임 UI(상황별 화면)
  * Python(PC)와 FPGA 간 **UART** 통신으로 노트 및 점수 데이터 송수신
  * **UVM**(Universal Verification Methodology) 기반 Top_Game 모듈 검증

---

## 담당 역할
- UART Receiver 설계
- <애상> 노트 ROM 제작
- ROM Reader, Note Controller 모듈 설계(진행 도중 구조 변경되어 삭제됨)
---

## 시스템 구조 및 설계 (System Architecture)
### 1. FPGA RTL Design
- FPGA 보드가 게임 컨트롤러 역할을 함.
#### 전체 Block Diagram
<img width="2159" height="1519" alt="image" src="https://github.com/user-attachments/assets/563a6f8d-b1f4-4de9-b5bb-7b9da61deb12" />

#### 모듈 상세
* **Main Controller**: 게임의 전체 제어 담당(상태 제어, VGA 화면 노트 생성, 판정, 점수 계산 모듈 포함)
  - Main State FSM
  <img width="1823" height="869" alt="image" src="https://github.com/user-attachments/assets/1aaaddf4-7ab8-4dfa-a114-dd7c8d2e33d2" />
  
  - 점수 판정 화면
    <img width="611" height="452" alt="image" src="https://github.com/user-attachments/assets/567895dd-9b90-4ac6-a27a-501d0f2ca21b" />

  - 판정, 점수 계산 기준(판정선 기준)
    <img width="557" height="119" alt="image" src="https://github.com/user-attachments/assets/62ed2e8a-99a2-4405-a3ea-eccd5e8fa182" />


* **VGA cam**: 640x480 @ 60Hz VGA 제어 및 노트 생성, 판정선, 점수판(SCORE) 등의 그래픽 overlay 처리
* **UART Sender**: 버튼 입력, 게임 state, 판정 결과 FPGA -> PC로 송신
  - FSM
    <img width="989" height="448" alt="image" src="https://github.com/user-attachments/assets/74eabe94-b1ef-403e-aaee-499ca3bdebf2" />

* **UART Receiver**: PC로부터 노트 레인 정보를 받아 Main Controller에 전달, game_done

### 2. Python
- 미디어 엔진 역할(GUI)
* **Main Controller의 state에 따른 화면 구성**
<img width="1127" height="216" alt="image" src="https://github.com/user-attachments/assets/70cf36c1-dc80-426c-8da2-510dac67c14e" />

* **음악별 노트 ROM**: 음악별 박자에 맞춰 떨어질 노트의 시간, 레인 정보가 담긴 ROM
* **UART 프로토콜을 통해 FPGA와 통신**: FPGA로부터 게임의 상태를 수신해 화면 띄우고 노트 생성 시 레인 정보 송신

---

## 검증 환경 (Verification)

### UVM 기반 환경 구축 (`Top_Game UVM`)
* SystemVerilog 및 **UVM (Universal Verification Methodology)**을 활용하여 탑 모듈(`Top_Game`) 검증 환경 구축
* Random Testbench 작성 및 Scoreboard를 통한 실시간 입력 대비 VGA 출력/게임 스코어 변화의 정확성 검증

---

## 주요 기능 시연 (Features & Demo)

1. **시작 화면 (Title Screen)**
   * `RHYTHM BEAT` 메인 타이틀 및 `PRESS START` 애니메이션
2. **카메라 인식 및 구역 탐지**
   * 카메라에 **빨간색 물체**가 포착되면 지정된 구역의 입력 이벤트 발생
3. **게임 플레이 (In-Game)**
   * 위에서 아래로 떨어지는 노트에 맞춰 탐지 영역을 터치하여 스코어 획득

---

## Trouble Shooting

* **Negative Slack Issue**
  - 문제: Negative Slack(WNS = 0.561ns) 발생
  - 원인: 점수 계산 부분에서 다수의 곱셈 및 나눗셈 연산이 하나의 조합논리 경로에 집중되어 있어 해당 경로의 Propagation Delay 증가
  - 해결: 중간 연산 결과 저장하는 register 추가하여 하나의 긴 조합논리 경로를 두 개의 경로로 분할
    <img width="620" height="168" alt="image" src="https://github.com/user-attachments/assets/4480ab4f-be01-4f8a-97d5-cc238db78333" />
* **Sender FIFO의 POP 시점 오류**
  - 문제: Sender에서 데이터 보내는 타이밍이 한 cycle 밀림
  - 원인: POP 시점을 FIFO로 데이터가 들어올 때가 아니라 다음 데이터가 들어올 때로 설계함
  - 해결: FIFO로 데이터가 들어오는 시점(FIFO !empty & Tx ready & !valid 조건이 충족됐을 때)에 POP 신호 발생
   <img width="477" height="240" alt="image" src="https://github.com/user-attachments/assets/b6bacbc7-ad0e-4894-b8a7-7b6ee5c6a3f2" />
* **전체 동작 및 UART 통신 구조 변경**
  - 문제: 게임 실행 시 내려오는 노트의 싱크가 완벽히 맞지 않음
  - 원인: FPGA와 PC(Python)이 각각 동일한 노트 ROM을 가지고 있고 게임 시작 시 양쪽의 타이머를 동시에 독립적으로 구동하여 실행하는 구조로 설계하여 UART 통신 딜레이와 양쪽의 clock 기준 차이로 인한 싱크 오차 발생
  - 해결: 노트 ROM은 Python만 가지고 있고 FPGA가 게임 전체 컨트롤러 역할을 하며 게임 중 노트가 발생할 때마다 Python에서 FPGA로 해당 노트의 레인 정보를 송신하는 구조로 변경해 통신 데이터 최소화 및 싱크 오차 해결

| 변경 전 구조 | 변경 후 구조 |
| :---: | :---: |
|<img width="1095" height="273" alt="image" src="https://github.com/user-attachments/assets/be231fc8-d72d-41e6-beb7-9bf8485e6724" /> | <img width="996" height="253" alt="image" src="https://github.com/user-attachments/assets/8a399ba0-2528-42f3-9815-ba504ac60ffc" /> |

## 고찰
- 처음 구조였던 동시 통신 방식이 매우 불안정하고 불확실한 방법이란 것을 깨닫게 되었다.
-  
- 중간에 설계 구조가 변경되는 문제가 있었지만 팀원들끼리 힘 

---
