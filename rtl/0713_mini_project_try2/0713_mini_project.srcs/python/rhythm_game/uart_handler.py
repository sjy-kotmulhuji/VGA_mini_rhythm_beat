# -*- coding: utf-8 -*-
"""
UART 시리얼 통신 핸들러 (uart_handler.py)

FPGA 보드와 PC 사이의 양방향 UART 통신을 관리합니다.
새로운 7바이트 프로토콜 규격에 따라 패킷을 해독(Parsing)하고,
엣지 디텍션을 적용하여 중복 이벤트를 방지한 뒤 이벤트 딕셔너리를 큐에 넣습니다.
"""

import threading
import queue
import time

try:
    import serial
    SERIAL_AVAILABLE = True
except ImportError:
    SERIAL_AVAILABLE = False
    print("[UART] pyserial 미설치 - 키보드 폴백 모드로 동작합니다.")
    print("[UART] UART를 사용하려면: pip install pyserial")

from config import UART_PORT, UART_BAUDRATE, UART_TIMEOUT

class UARTHandler:
    def __init__(self):
        self.event_queue = queue.Queue()
        self.serial_port = None
        self.running = False
        self.thread = None
        self.connected = False

    def start(self):
        if not SERIAL_AVAILABLE:
            print("[UART] pyserial 없음 - 키보드 폴백 모드")
            return False

        try:
            self.serial_port = serial.Serial(
                port=UART_PORT,
                baudrate=UART_BAUDRATE,
                bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE,
                stopbits=serial.STOPBITS_ONE,
                timeout=UART_TIMEOUT,
            )
            self.connected = True
            self.running = True

            self.thread = threading.Thread(target=self._read_loop, daemon=True)
            self.thread.start()

            print(f"[UART] {UART_PORT} 연결 성공 (Baud: {UART_BAUDRATE})")
            return True

        except serial.SerialException as e:
            print(f"[UART] 연결 실패: {e}")
            print("[UART] 키보드 폴백 모드로 전환합니다.")
            self.connected = False
            return False

    def stop(self):
        self.running = False
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=1.0)
        if self.serial_port and self.serial_port.is_open:
            self.serial_port.close()
            print("[UART] 연결 종료")

    def _read_loop(self):
        buffer = bytearray()
        
        while self.running:
            try:
                if self.serial_port and self.serial_port.in_waiting > 0:
                    data = self.serial_port.read(self.serial_port.in_waiting)
                    buffer.extend(data)
                    
                    # 7바이트 이상 쌓였을 때 파싱 시도
                    while len(buffer) >= 7:
                        # 헤더(0xFF) 찾기
                        if buffer[0] != 0xFF:
                            buffer.pop(0) # 헤더가 아니면 1바이트 버림
                            continue
                            
                        # 헤더를 찾았고 7바이트가 확보된 상태
                        packet = buffer[:7]
                        del buffer[:7] # 파싱할 패킷 버퍼에서 제거
                        
                        self._parse_packet(packet)
                else:
                    time.sleep(0.001)
            except Exception as e:
                print(f"[UART] 수신 오류: {e}")
                self.running = False
                self.connected = False
                break

    def _parse_packet(self, packet):
        # packet[0] == 0xFF (Header)
        
        # Byte 2 (Control)
        b2 = packet[1]
        state = (b2 >> 4) & 0x07
        up = (b2 >> 3) & 0x01
        down = (b2 >> 2) & 0x01
        right = (b2 >> 1) & 0x01
        left = b2 & 0x01
        
        # Byte 3 (Data)
        b3 = packet[2]
        hit = (b3 >> 4) & 0x01
        fever = (b3 >> 3) & 0x01
        perfect = (b3 >> 2) & 0x01
        good = (b3 >> 1) & 0x01
        miss = b3 & 0x01
        
        # Byte 4 (Combo)
        combo = packet[3]
        
        # Byte 5, 6, 7 (Score)
        score_l = packet[4]
        score_m = packet[5]
        score_h = packet[6]
        score = (score_h << 16) | (score_m << 8) | score_l
        
        # 이벤트 딕셔너리 생성 (들어오는 즉시 모두 유효한 이벤트로 간주)
        event = {
            "state": state,
            "up": True if up == 1 else False,
            "down": True if down == 1 else False,
            "right": True if right == 1 else False,
            "left": True if left == 1 else False,
            "perfect": True if perfect == 1 else False,
            "good": True if good == 1 else False,
            "miss": True if miss == 1 else False,
            "combo": combo,
            "score": score
        }
        
        # 큐에 넣기 (수신된 패킷 1개당 1번의 이벤트 폭발)
        self.event_queue.put(event)

    def get_event(self):
        try:
            return self.event_queue.get_nowait()
        except queue.Empty:
            return None

    def send_to_fpga(self, data):
        if not self.connected or not self.serial_port:
            return
        try:
            if isinstance(data, int):
                self.serial_port.write(bytes([data & 0xFF]))
            elif isinstance(data, bytes):
                self.serial_port.write(data)
        except Exception as e:
            print(f"[UART] 송신 오류: {e}")

    def is_connected(self):
        return self.connected
