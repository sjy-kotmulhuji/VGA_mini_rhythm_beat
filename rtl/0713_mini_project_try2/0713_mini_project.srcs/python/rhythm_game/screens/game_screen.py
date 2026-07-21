# -*- coding: utf-8 -*-
"""
게임 화면 (Game Screen) 모듈

실제로 플레이어가 리듬 액션 게임을 조작하고 노트를 타격하는 메인 화면입니다.
가짜 3D 투시(Perspective)를 이용해 상단 중앙에서 하단 가장자리로
넓게 퍼지는 레인을 렌더링하여 고전 아케이드 리듬 게임의 원근감을 시뮬레이션합니다.

주요 구성 요소:
- GameScreen: 화면의 라이프사이클 관리, 물리적인 렌더링, 이벤트 감지 처리.
- Note: 각 레인 위에서 판정선을 향해 스크롤 되는 노트 객체 모델.
- HitParticle / HitFlash: 노트를 정확히 눌렀을 때 터져나오는 화려한 네온 파티클과 광원 효과.

FPGA 통신 연동:
  - UART 채널로부터 전달되는 트리거 코드에 따라 (0x10 ~ 0x13)
  - FPGA 하드웨어 버튼이 소프트웨어의 키보드(A,S,D,F)와 똑같은 타격 동작을 수행하도록
    `handle_trigger()` 내부에서 `TRIGGER_KEY_MAP`을 조회해 판정을 실행합니다.
"""

import pygame
import math
import random
import os

from screens.base_screen import BaseScreen
import config
# 게임 내 세부 난이도 파라미터 및 색상을 전역 설정에서 통일시켜 불러옴
from config import (
    COLOR_BG_DARK, COLOR_BG_NAVY,
    COLOR_NEON_CYAN, COLOR_NEON_PINK, COLOR_NEON_PURPLE, COLOR_NEON_BLUE,
    COLOR_WHITE, COLOR_GRAY, COLOR_TEXT_DIM,
    NOTE_SPEED, HIT_LINE_PROGRESS, JUDGE_MARGIN, JUDGE_PERFECT_THRESHOLD,
    SCORE_PERFECT, SCORE_GOOD,
    PARTICLE_COUNT, PARTICLE_MIN_SIZE, PARTICLE_MAX_SIZE,
    PARTICLE_MIN_SPEED, PARTICLE_MAX_SPEED,
)
import leaderboard

# ============================================================
# 색상 상수
# ============================================================
# 인게임 플레이의 배경, 그라데이션, 그리고 트랙 등을 렌더링하기 위한 레트로 다크 톤 조합
C_BG_GAME = (5, 2, 18)            # 깊고 어두운 남색 계열 최상단 배경
C_BG_GRADIENT = (12, 4, 30)       # 화면 하단으로 내려올수록 짙어지는 바닥 그라데이션
C_LANE_BG = (18, 8, 45)           # 트랙 안쪽의 기본 불투명 바닥 색상
C_LANE_LINE = (70, 35, 140)       # 레인을 4칸으로 나누는 세로줄의 기본 컬러 (밝은 퍼플)
C_LANE_GLOW = (0, 200, 255)       # 레인 클릭 시 순간적으로 번지는 글로우 효과
C_HIT_LINE = (255, 100, 200)      # 타격 타이밍을 알려주는 하단 가로 선 (네온 핑크)
C_GRID_LINE = (30, 15, 70)        # 시각적인 속도감을 더해주는 수평 이동선용 어두운 보라
C_TRACK_EDGE = (120, 40, 220)     # 게임 영역 트랙의 외곽 양 모서리 빛기둥 색상

# 각 4개의 레인(A,S,D,F 키 매핑) 고유의 식별 색상 및 번짐(글로우) 코어 
C_NOTE_COLORS = [
    (0, 220, 255),    # 레인 0 (A) - 밝고 시원한 시안
    (255, 50, 180),   # 레인 1 (S) - 핫 핑크
    (180, 80, 255),   # 레인 2 (D) - 강렬한 퍼플
    (50, 255, 150),   # 레인 3 (F) - 네온 민트 그린
]

C_NOTE_GLOW = [
    (0, 180, 220),
    (220, 30, 150),
    (150, 60, 220),
    (30, 220, 120),
]


# ============================================================
# 시각 이펙트 클래스
# ============================================================
class HitParticle:
    """
    타격 파티클 이펙트
    
    사용자가 정확한 타이밍에 노트를 눌렀을 때 타격 지점(판정선)을 중심으로
    터져나가는 작은 파편 가루 조각입니다. 중력의 영향을 받아 포물선을 그리며 사라집니다.
    """
    def __init__(self, x, y, color):
        """파티클의 초기 위치와 랜덤한 분출 각도/속력을 세팅합니다."""
        self.x = x
        self.y = y
        self.color = color
        self.vx = random.uniform(-150, 150)
        self.vy = random.uniform(-200, -50)
        self.life = 1.0
        self.size = random.uniform(2, 5)

    def update(self, dt):
        """중력값을 적용하여 y속도를 증가시키며 위치를 업데이트합니다."""
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.vy += 300 * dt  # 아래 방향으로 떨어지는 중력
        self.life -= dt * 2.5
        return self.life > 0

    def draw(self, surface):
        """생명 주기(life)에 따라 크기와 알파값을 점점 줄이며 그립니다."""
        alpha = int(255 * max(0, self.life))
        if alpha > 5:
            s = max(1, int(self.size * self.life * 2))
            color = self.color[:3]
            pygame.draw.circle(surface, color, (int(self.x), int(self.y)), s)


class HitFlash:
    """
    타격 빔 플래시 이펙트
    
    파티클과 동시에 판정선 가로축을 중심으로 넓고 선명한 십자/가로선 형태의
    빛줄기가 매우 짧은 시간 반짝이는 이펙트를 만듭니다. (Perfect 판정 시 더욱 강렬함)
    """
    def __init__(self, x, y, width, color, is_perfect=False):
        self.x = x
        self.y = y
        self.width = width
        self.color = color
        self.is_perfect = is_perfect
        self.life = 1.0
        # Perfect 여부에 따라 플래시가 남아있는 최대 유지 프레임 시간을 달리 둠
        self.max_life = 0.4 if is_perfect else 0.25

    def update(self, dt):
        self.life -= dt / self.max_life
        return self.life > 0

    def draw(self, surface):
        if self.life <= 0:
            return
        
        alpha = max(0, int(200 * self.life))
        spread = int((1.0 - self.life) * (80 if self.is_perfect else 40))

        # 좌우로 길게 뻗어나가는 빔의 범위를 포괄하는 투명 도화지 생성
        flash_surf = pygame.Surface((self.width + spread * 2, spread * 2 + 6), pygame.SRCALPHA)
        cx = flash_surf.get_width() // 2
        cy = flash_surf.get_height() // 2

        # 3단계의 두께와 투명도를 가진 흐린 네모(선)들을 겹쳐 그려 글로우 효과
        for i in range(3):
            layer_alpha = max(0, alpha - i * 50)
            h = max(1, spread - i * 8)
            w = self.width + spread * 2 - i * 20
            if w > 0 and h > 0 and layer_alpha > 0:
                rect = pygame.Rect(cx - w // 2, cy - h // 2, w, h)
                pygame.draw.rect(flash_surf, (*self.color[:3], layer_alpha), rect, border_radius=max(1, h // 2))

        # 가장 중심이 되는 흰색에 가까운 얇고 밝은 핵(Core) 선 그리기
        bright = (min(255, self.color[0] + 100), min(255, self.color[1] + 100), min(255, self.color[2] + 100))
        core_alpha = max(0, int(255 * self.life))
        pygame.draw.line(flash_surf, (*bright, core_alpha),
                        (cx - self.width // 2, cy), (cx + self.width // 2, cy), 2)

        surface.blit(flash_surf, (int(self.x - flash_surf.get_width() // 2),
                                   int(self.y - flash_surf.get_height() // 2)))


# ============================================================
# 노트 모델 클래스
# ============================================================
class Note:
    """
    떨어지는 개별 리듬 노트 객체

    생성 시각과 도달 시각을 기반으로 게임 내 프레임 시간에 의존해
    자신의 현재 y좌표(진행률 0.0 ~ 1.0)를 스스로 반환합니다.
    """
    def __init__(self, lane, spawn_time, hit_time):
        self.lane = lane
        self.spawn_time = spawn_time
        self.hit_time = hit_time
        
        # 맞췄는지 놓쳤는지의 판정 플래그
        self.is_hit = False
        self.is_missed = False
        self.is_sent = False

    def get_progress(self, current_time):
        """
        현시점의 곡(혹은 게임) 플레이 시간을 넣으면 노트가 화면 상단부터
        판정선까지 내려온 진행 백분율(비율)을 0.0 ~ 1.0 사이 값으로 계산해 넘겨줍니다.
        """
        total_time = self.hit_time - self.spawn_time
        elapsed = current_time - self.spawn_time
        return elapsed / total_time


# ============================================================
# 메인 게임 스크린 클래스
# ============================================================
class GameScreen(BaseScreen):
    """게임 플레이 화면 및 전체적인 노트와 판정 렌더링/로직 시스템 제어기"""

    # --------------------------------------------------------
    # 초기화 
    # --------------------------------------------------------
    def __init__(self, screen, clock, uart=None):
        super().__init__(screen, clock)
        self.uart = uart
        self.sw = screen.get_width()
        self.sh = screen.get_height()

        self.time = 0.0

        # 키 맵핑 정보 세팅 (A, S, D, F 키보드 물리 키 대응 배열)
        self.keys = [pygame.K_a, pygame.K_s, pygame.K_d, pygame.K_f]
        self.key_states = [False, False, False, False]
        self.key_glows = [0.0, 0.0, 0.0, 0.0]  # 키를 눌렀을 때 레인 하이라이트 투명도 

        self.notes = []
        self.combo = 0
        self.max_combo = 0
        self.score = 0
        # 화면 중앙 부근에 잠깐 뜨고 사라질 판정 텍스트들({"text": "PERFECT", "time": ..., "color": ...})
        self.judgments = []  

        self.hit_particles = []
        self.hit_flashes = []

        # --- UI 애니메이션용 변수들 ---
        self.score_display = 0          # 실제 점수판이 부드럽게 올라가도록 지연 계산하는 표시용 점수
        self.score_pulse = 0.0          # 점수가 오를 때 테두리가 반짝거리는 펄스 효과 플래그
        self.combo_bounce = 0.0         # 콤보 수가 상승할 때 글씨가 쿵 뛰는 바운스 효과치
        self.prev_combo = 0             

        # 우주 공간을 날아가는 듯한 별 점들
        self.bg_stars = []
        for _ in range(30):
            self.bg_stars.append({
                "x": random.randint(0, self.sw),
                "y": random.randint(0, self.sh),
                "size": random.randint(1, 2),
                "alpha": random.randint(80, 200),
                "pulse_speed": random.uniform(1.0, 3.0),
                "pulse_offset": random.uniform(0, math.pi * 2),
            })

        # 다가오는 트랙망 바닥 선 
        self.grid_scroll = 0.0

        # 임시 노트 생성기용 전역 파라미터 로드
        self.next_note_time = self.time + 2.0
        self.note_speed = NOTE_SPEED  
        self.hit_line_progress = HIT_LINE_PROGRESS  

        # 정적 파일들(폰트 등) 준비
        self._init_fonts()
        self._init_cached_surfaces()
        self.reset()

    def reset(self):
        """
        곡을 선택하고 화면이 시작될 때마다 과거 데이터 리셋 및 초기화.
        만약 메모리에 롬 파일 읽기 기능이 있다면, 이 함수 안에서 다시 로드하고 첫 변수를 세팅합니다.
        """
        self.time = 0.0
        self.play_time = 0.0
        self.state = "COUNTDOWN_START"
        self.countdown_time = 3.0
        self.key_states = [False, False, False, False]
        self.key_glows = [0.0, 0.0, 0.0, 0.0]
        self.last_lane = 0
        self.notes = []
        self.combo = 0
        self.max_combo = 0
        self.score = 0
        self.judgments = []
        self.hit_particles = []
        self.hit_flashes = []
        self.score_display = 0
        self.score_pulse = 0.0
        self.combo_bounce = 0.0
        self.prev_combo = 0
        self.next_note_time = self.time + 2.0
        self.game_over_sent = False
        
        self._load_song()

    def _load_song(self):
        """ROM 데이터를 읽어와 self.notes에 로드합니다."""
        song_info = config.SONG_LIST[config.SELECTED_SONG_INDEX]
        mem_filename = song_info.get("mem_file")
        if not mem_filename:
            return
            
        project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        rom_path = os.path.join(project_root, "rom_data", mem_filename)
        
        try:
            with open(rom_path, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or len(line) < 8:
                        continue
                        
                    frame_hex = line[:4]
                    lane_hex = line[4:8]
                    
                    frame = int(frame_hex, 16)
                    lane_val = int(lane_hex, 16)
                    
                    if lane_val & 0x08: lane = 0
                    elif lane_val & 0x04: lane = 1
                    elif lane_val & 0x02: lane = 2
                    elif lane_val & 0x01: lane = 3
                    else: continue
                    
                    # 카운트다운(3초) 이후부터 떨어지도록 스폰 시간에 3초 가산
                    spawn_time = (frame * config.FRAME_MULTIPLIER) * 0.0168 + 3.0
                    hit_time = spawn_time + config.NOTE_SPEED
                    self.notes.append(Note(lane, spawn_time, hit_time))
        except Exception as e:
            print(f"Failed to load rom data: {e}")

    # --------------------------------------------------------
    # 렌더링 리소스 준비 / 캐싱
    # --------------------------------------------------------
    def _init_cached_surfaces(self):
        """
        정적인 뒷배경이나 복잡하지만 움직이지 않는 선들을
        단 한번만 렌더링하여 Surface 형태로 캐싱하여 프레임 드랍을 막습니다.
        """
        # 1. 배경 화면 캐싱
        self._bg_surface = pygame.Surface((self.sw, self.sh))
        for y in range(0, self.sh, 2):
            ratio = y / self.sh
            r = int(C_BG_GAME[0] * (1 - ratio) + C_BG_GRADIENT[0] * ratio)
            g = int(C_BG_GAME[1] * (1 - ratio) + C_BG_GRADIENT[1] * ratio)
            b = int(C_BG_GAME[2] * (1 - ratio) + C_BG_GRADIENT[2] * ratio)
            pygame.draw.rect(self._bg_surface, (r, g, b), (0, y, self.sw, 2))

        # 2. CRT 브라운관 텍스쳐 필터 마스크
        self._scanline_surface = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        for y in range(0, self.sh, 3):
            pygame.draw.line(self._scanline_surface, (0, 0, 0, 20), (0, y), (self.sw, y), 1)

        # 3. 빈 알파 캔버스 (매번 투명 효과를 덮어 그릴 때 쓰임)
        self._track_overlay = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)

        # 4. 트랙 좌우 테두리의 두꺼운 네온 글로우 선
        self._track_border = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        _, top_w = self._get_projection(0)
        _, bot_w = self._get_projection(1.0)
        top_lx = (self.sw - top_w) / 2
        top_rx = top_lx + top_w
        bot_lx = (self.sw - bot_w) / 2
        bot_rx = bot_lx + bot_w
        
        # 바깥쪽 흐린 외곽 글로우 처리 (그라데이션 빛번짐)
        for gi in range(12):
            alpha = max(0, 45 - gi * 4)
            pygame.draw.line(self._track_border, (*C_TRACK_EDGE[:3], alpha),
                           (int(top_lx) - gi, 0), (int(bot_lx) - gi, self.sh), 1)
            pygame.draw.line(self._track_border, (*C_TRACK_EDGE[:3], alpha),
                           (int(top_rx) + gi, 0), (int(bot_rx) + gi, self.sh), 1)
                           
        # 안쪽 코어 라인
        for gi in range(3):
            alpha = max(0, 180 - gi * 50)
            pygame.draw.line(self._track_border, (*C_TRACK_EDGE[:3], alpha),
                           (int(top_lx) - gi, 0), (int(bot_lx) - gi, self.sh), 2)
            pygame.draw.line(self._track_border, (*C_TRACK_EDGE[:3], alpha),
                           (int(top_rx) + gi, 0), (int(bot_rx) + gi, self.sh), 2)

        # 5. 4개의 레인을 세로로 분할하는 3개의 라인 + 맨 우측 라인
        self._lane_lines = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        segments = 25
        for i in range(segments):
            p1 = i / segments
            p2 = (i + 1) / segments
            y1, w1 = self._get_projection(p1)
            y2, w2 = self._get_projection(p2)
            line_alpha = min(255, int(240 + 160 * (p1 ** 0.5)))
            for lane in range(4):
                x1, lw1 = self._get_lane_x(lane, w1)
                x2, lw2 = self._get_lane_x(lane, w2)
                pygame.draw.line(self._lane_lines, (*C_LANE_LINE[:3], line_alpha),
                               (int(x1), int(y1)), (int(x2), int(y2)), 3)
                if lane == 3:
                    pygame.draw.line(self._lane_lines, (*C_LANE_LINE[:3], line_alpha),
                                   (int(x1 + lw1), int(y1)), (int(x2 + lw2), int(y2)), 3)

        # 6. 하단 고정 타격 가이드(판정선) 이미지 캐싱
        hit_y, hit_w = self._get_projection(self.hit_line_progress)
        hit_x, _ = self._get_lane_x(0, hit_w)
        self._hitline_surface = pygame.Surface((self.sw, 50), pygame.SRCALPHA)
        for gi in range(8):
            alpha = max(0, 50 - gi * 6)
            pygame.draw.line(self._hitline_surface, (*C_HIT_LINE[:3], alpha),
                           (int(hit_x), 25 - gi), (int(hit_x + hit_w), 25 - gi), 1)
            pygame.draw.line(self._hitline_surface, (*C_HIT_LINE[:3], alpha),
                           (int(hit_x), 25 + gi), (int(hit_x + hit_w), 25 + gi), 1)
        pygame.draw.line(self._hitline_surface, C_HIT_LINE,
                        (int(hit_x), 25), (int(hit_x + hit_w), 25), 3)
        pygame.draw.line(self._hitline_surface, (255, 200, 240),
                        (int(hit_x), 25), (int(hit_x + hit_w), 25), 1)
        self._hitline_y = hit_y

        # 7. 레인의 바닥 질감 타일. 짝수 레인과 홀수 레인의 색을 조금 달리하여 구분이 명확하도록.
        self._track_base = pygame.Surface((self.sw, self.sh), pygame.SRCALPHA)
        for i in range(segments):
            p1 = i / segments
            p2 = (i + 1) / segments
            y1, w1 = self._get_projection(p1)
            y2, w2 = self._get_projection(p2)
            
            for lane in range(4):
                x1, lw1 = self._get_lane_x(lane, w1)
                x2, lw2 = self._get_lane_x(lane, w2)
                pts = [(x1, y1), (x1 + lw1, y1), (x2 + lw2, y2), (x2, y2)]
                
                if lane % 2 == 0:
                    lane_color = (22, 10, 50, 240)
                else:
                    lane_color = (30, 15, 60, 240)
                    
                pygame.draw.polygon(self._track_base, lane_color, pts)

    def _init_fonts(self):
        """점수 표시 및 판정 이펙트를 그릴 폰트 준비 과정"""
        korean_fonts = ["malgun gothic", "malgungothic", "gulim", "dotum"]
        font_name = None
        for fname in korean_fonts:
            if fname in [f.lower() for f in pygame.font.get_fonts()]:
                font_name = fname
                break

        scale = self.sh / 600.0
        if font_name:
            self.font_combo = pygame.font.SysFont(font_name, int(58 * scale), bold=True)
            self.font_combo_label = pygame.font.SysFont(font_name, int(16 * scale), bold=True)
            self.font_score = pygame.font.SysFont(font_name, int(32 * scale), bold=True)
            self.font_score_label = pygame.font.SysFont(font_name, int(12 * scale), bold=True)
            self.font_judge = pygame.font.SysFont(font_name, int(52 * scale), bold=True)
            self.font_key = pygame.font.SysFont(font_name, int(26 * scale), bold=True)
        else:
            self.font_combo = pygame.font.Font(None, int(72 * scale))
            self.font_combo_label = pygame.font.Font(None, int(20 * scale))
            self.font_score = pygame.font.Font(None, int(40 * scale))
            self.font_score_label = pygame.font.Font(None, int(16 * scale))
            self.font_judge = pygame.font.Font(None, int(66 * scale))
            self.font_key = pygame.font.Font(None, int(32 * scale))

    def _get_projection(self, p):
        """
        화면 최상단 0.0에서 최하단 1.0으로 떨어지는 진행 값에 따른 가상의 3D 투시 계산식을 반환.
        원근감(Perspective)을 가진 트랙에서 속도가 일정하게 느껴지도록 
        픽셀 속도를 아래로 갈수록 기하급수적으로 증가시킵니다.
        """
        # 3D 공간에서 일정한 속도로 다가오는 물체는 화면상에서 2차 곡선 형태로 가속하며 내려옵니다.
        eased_p = p ** 2.4

        y = self.sh * eased_p
        ratio = y / self.sh

        top_w = self.sw * 0.18    
        bottom_w = self.sw * 0.85 

        w = top_w + (bottom_w - top_w) * ratio
        return y, w

    def _get_lane_x(self, lane, w, total_lanes=4):
        """4분할된 특정 레인 폭과 x축 시작 위치 연산"""
        lane_w = w / total_lanes
        x = (self.sw / 2) - (w / 2) + (lane * lane_w)
        return x, lane_w

    def _add_judgment(self, text, color, combo=0, added_score=0):
        """판정 성공 시 화면 상단 텍스트 및 콤보 UI 버블 팝업 메시지를 쌓습니다."""
        self.judgments.append({
            "text": text,
            "color": color,
            "spawn_time": self.time,
            "duration": 0.7,
            "combo": combo,
            "added_score": added_score,
        })

    # --------------------------------------------------------
    # 이벤트 처리 및 업데이트 
    # --------------------------------------------------------
    def handle_event(self, event):
        """
        컴퓨터 키보드를 눌렀을 때의 조작(A,S,D,F 혹은 ESC) 
        """
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.next_screen = "select"
            else:
                for i, key in enumerate(self.keys):
                    if event.key == key:
                        self.key_states[i] = True
                        self.key_glows[i] = 1.0  # 바닥 타일 하이라이트를 최대로 점등
                        self.last_lane = i

        elif event.type == pygame.KEYUP:
            for i, key in enumerate(self.keys):
                if event.key == key:
                    self.key_states[i] = False

    def handle_trigger(self, trigger):
        """
        FPGA UART 트리거 신호 처리 
        키보드가 아닌 보드의 물리적 버튼 신호를 받아와서 내부적으로는 동일하게 처리합니다.
        """
    def handle_trigger(self, event):
        """
        UART 7바이트 패킷에서 추출된 딕셔너리 이벤트를 처리합니다.
        """
        if not isinstance(event, dict):
            return
            
        # 1. State 동기화 (FPGA -> PC 화면 전환)
        fpga_state = event.get("state", 0)
        if fpga_state == 2 and self.state != "COUNTDOWN_START":
            self.state = "COUNTDOWN_START"
            self.countdown_time = 3.0
        elif fpga_state == 3 and self.state != "PLAYING":
            self.state = "PLAYING"
        elif fpga_state >= 4 and self.state == "PLAYING":
            self.state = "COUNTDOWN_END"
            self.countdown_time = 5.0
            
        # 2. 버튼 입력 시 해당 레인 하이라이트 (Left=0, Up=1, Down=2, Right=3)
        if event.get("left"):
            self.key_glows[0] = 1.0
            self.last_lane = 0
        if event.get("up"):
            self.key_glows[1] = 1.0
            self.last_lane = 1
        if event.get("down"):
            self.key_glows[2] = 1.0
            self.last_lane = 2
        if event.get("right"):
            self.key_glows[3] = 1.0
            self.last_lane = 3

        # 3. 판정 신호 수신 시 이펙트 폭발 및 점수 동기화
        lane = getattr(self, "last_lane", 0)
        hit_y, hit_w = self._get_projection(self.hit_line_progress)
        hit_x, hit_lw = self._get_lane_x(lane, hit_w)
        px = hit_x + hit_lw / 2

        if event.get("perfect"):
            for _ in range(15):
                self.hit_particles.append(HitParticle(px, hit_y, C_NOTE_COLORS[lane]))
            flash_x = (self.sw - hit_w) / 2 + hit_w / 2
            self.hit_flashes.append(HitFlash(flash_x, hit_y, int(hit_w), C_NOTE_COLORS[lane], is_perfect=True))
            self._add_judgment("PERFECT!", COLOR_NEON_CYAN, event.get("combo", 0), 0)
            
        elif event.get("good"):
            for _ in range(8):
                self.hit_particles.append(HitParticle(px, hit_y, C_NOTE_COLORS[lane]))
            self.hit_flashes.append(HitFlash(px, hit_y, int(hit_lw), C_NOTE_COLORS[lane], is_perfect=False))
            self._add_judgment("GOOD", (255, 200, 0), event.get("combo", 0), 0)
            
        elif event.get("miss"):
            self._add_judgment("MISS", (255, 50, 50), 0, 0)
            
        # FPGA의 점수/콤보로 무조건 덮어쓰기 (강력한 동기화)
        if "score" in event:
            self.score = event["score"]
        if "combo" in event:
            self.combo = event["combo"]
            self.max_combo = max(self.max_combo, self.combo)

    def update(self, dt):
        """
        게임 진행 상황(시간, 점수 게이지, 이펙트 남은 수명, 노트 이동) 등 모든
        가상 세계의 물리 시뮬레이션을 프레임당 업데이트합니다.
        """
        self.time += dt

        # 키를 떼면 서서히 불빛이 꺼지도록 함 
        for i in range(4):
            if not self.key_states[i] and self.key_glows[i] > 0:
                self.key_glows[i] = max(0.0, self.key_glows[i] - dt * 4.0)

        if self.state == "COUNTDOWN_START":
            self.countdown_time -= dt
            if self.countdown_time <= 0:
                self.state = "PLAYING"
        elif self.state == "PLAYING":
            self.play_time += dt
            
            # 내려오는 노트들의 진척도 확인
            active_notes = []
            for note in self.notes:
                if note.is_hit or note.is_missed:
                    continue

                # 스폰 타임이 되었고 아직 FPGA로 송신하지 않았다면 송신
                if self.play_time >= note.spawn_time and not note.is_sent:
                    note.is_sent = True
                    lane_mask = 1 << note.lane
                    cmd_byte = 0x80 | lane_mask
                    if self.uart and self.uart.is_connected():
                        self.uart.send_to_fpga(cmd_byte)
                        print(f"[UART] 노트 스폰 송신: 레인 {note.lane} (cmd: 0x{cmd_byte:02X})")

                p = note.get_progress(self.play_time)
                # 시야를 벗어난 경우 청소 (Miss 처리는 FPGA에서 하므로 여기선 시각적 삭제만)
                if p > self.hit_line_progress + 0.15:  
                    note.is_missed = True
                    continue

                active_notes.append(note)
            self.notes = active_notes

            # 모든 노트가 스폰 완료되고 리스트가 비어있을 때 (곡 종료)
            if len(self.notes) == 0 and not self.game_over_sent:
                self.game_over_sent = True
                if self.uart and self.uart.is_connected():
                    self.uart.send_to_fpga(0x90)
                    print("[UART] 게임 오버 패킷 송신 (0x90)")
        elif self.state == "COUNTDOWN_END":
            self.countdown_time -= dt
            if self.countdown_time <= 0:
                # 결과 화면으로 전환 및 점수 저장
                leaderboard.save_score("PLAYER", self.score, self.max_combo)
                config.LAST_SCORE = self.score
                config.LAST_COMBO = self.max_combo
                self.next_screen = "result"

        # 유효시간이 다 지난 팝업 텍스트들은 자동 소거시킴 
        self.judgments = [j for j in self.judgments if self.time - j["spawn_time"] < j["duration"]]

        # 입자 그래픽 처리 
        self.hit_particles = [p for p in self.hit_particles if p.update(dt)]
        self.hit_flashes = [f for f in self.hit_flashes if f.update(dt)]

        # 배경 선분 무한 스크롤 착시 
        self.grid_scroll = (self.grid_scroll + dt * 0.5) % 1.0

        # UI 스코어 보드의 부드러운 애니메이션 차익 가산 연산 
        if self.score_display < self.score:
            diff = self.score - self.score_display
            self.score_display += max(1, int(diff * dt * 8))
            if self.score_display > self.score:
                self.score_display = self.score

        if self.score_pulse > 0:
            self.score_pulse = max(0.0, self.score_pulse - dt * 3.0)

        if self.combo_bounce > 0:
            self.combo_bounce = max(0.0, self.combo_bounce - dt * 5.0)

        if self.combo != self.prev_combo:
            if self.combo > self.prev_combo:
                self.combo_bounce = 1.0
                self.score_pulse = 1.0
            self.prev_combo = self.combo

    # --------------------------------------------------------
    # 물리적 화면 렌더링 
    # --------------------------------------------------------
    def _draw_track(self):
        self.screen.blit(self._bg_surface, (0, 0))
        for star in self.bg_stars:
            pulse = 0.5 + 0.5 * math.sin(self.time * star["pulse_speed"] + star["pulse_offset"])
            if pulse > 0.3:
                pygame.draw.circle(self.screen, (200, 210, 255), (star["x"], star["y"]), star["size"])
        self.screen.blit(self._track_border, (0, 0))
        self.screen.blit(self._track_base, (0, 0))
        
        any_glow = any(g > 0 for g in self.key_glows)
        if any_glow:
            self._track_overlay.fill((0, 0, 0, 0))
            segments = 25
            for i in range(segments):
                p1, p2 = i / segments, (i + 1) / segments
                y1, w1 = self._get_projection(p1)
                y2, w2 = self._get_projection(p2)
                for lane in range(4):
                    if self.key_glows[lane] <= 0: continue
                    x1, lw1 = self._get_lane_x(lane, w1)
                    x2, lw2 = self._get_lane_x(lane, w2)
                    pygame.draw.polygon(self._track_overlay, (*C_NOTE_COLORS[lane], min(255, int(80 * self.key_glows[lane]))), [(x1, y1), (x1+lw1, y1), (x2+lw2, y2), (x2, y2)])
            self.screen.blit(self._track_overlay, (0, 0))
        self.screen.blit(self._lane_lines, (0, 0))
        self._track_overlay.fill((0, 0, 0, 0))
        for gi in range(12):
            gp = ((gi / 12) + self.grid_scroll) % 1.0
            gy, gw = self._get_projection(gp)
            gx_start = (self.sw - gw) / 2
            alpha = int(25 * gp)
            if alpha > 3:
                pygame.draw.line(self._track_overlay, (*C_GRID_LINE[:3], alpha), (int(gx_start), int(gy)), (int(gx_start + gw), int(gy)), 1)
        self.screen.blit(self._track_overlay, (0, 0))
        self.screen.blit(self._hitline_surface, (0, self._hitline_y - 25))
        
        # 판정선 위의 다이아몬드 아이콘 표시
        hit_y, hit_w = self._get_projection(self.hit_line_progress)
        for lane in range(4):
            mx, _ = self._get_lane_x(lane, hit_w)
            mx += hit_w / 8
            my = self._hitline_y
            
            if self.key_glows[lane] > 0:
                dia_color = C_NOTE_COLORS[lane]
                dia_size = 7
            else:
                dia_color = (100, 80, 140)
                dia_size = 5
                
            pts = [(mx, my - dia_size), (mx + dia_size, my),
                   (mx, my + dia_size), (mx - dia_size, my)]
            pygame.draw.polygon(self.screen, dia_color, pts)

    def _draw_notes(self):
        """가상 위치 정보를 가져와 모니터 픽셀에 맞게 화면의 크기를 키워 그립니다."""
        for note in self.notes:
            p = note.get_progress(self.time)
            if p < 0:
                continue

            actual_p = p * self.hit_line_progress
            y, w = self._get_projection(actual_p)
            x, lw = self._get_lane_x(note.lane, w)
            note_h = max(4, int(self.sh * 0.035 * (0.3 + actual_p * 0.7)))
            color = C_NOTE_COLORS[note.lane]

            margin = lw * 0.08
            nx = int(x + margin)
            nw = int(lw - margin * 2)
            ny = int(y - note_h / 2)
            radius = max(1, int(note_h / 2))

            if nw > 0 and note_h > 0:
                note_rect = pygame.Rect(nx, ny, nw, note_h)
                pygame.draw.rect(self.screen, color, note_rect, border_radius=radius)

                h_margin = max(2, int(note_h * 0.15))
                hl_rect = pygame.Rect(nx + 2, ny + h_margin, max(1, nw - 4), max(1, note_h - h_margin * 2))
                bright_color = (
                    min(255, color[0] + 80),
                    min(255, color[1] + 80),
                    min(255, color[2] + 80),
                )
                if hl_rect.width > 0 and hl_rect.height > 0:
                    pygame.draw.rect(self.screen, bright_color, hl_rect,
                                   border_radius=max(1, int(note_h / 3)))

    def _draw_hit_particles(self):
        """이펙트 오브젝트 표출 위임 함수"""
        for flash in self.hit_flashes:
            flash.draw(self.screen)
        for particle in self.hit_particles:
            particle.draw(self.screen)

    def _draw_ui(self):
        """모서리 및 상단 중앙 등에 스코어 텍스트, 키보드 조작 가이드 안내서 등을 출력합니다."""
        cx = self.sw // 2
        cy = self.sh // 2

        # 1. 왼쪽 위 점수판 
        panel_w = int(self.sw * 0.22)
        panel_h = int(self.sh * 0.11)
        panel_x = 16
        panel_y = 12

        panel_surf = pygame.Surface((panel_w, panel_h), pygame.SRCALPHA)
        pygame.draw.rect(panel_surf, (10, 5, 30, 140), (0, 0, panel_w, panel_h), border_radius=10)
        
        if self.score_pulse > 0:
            glow_alpha = int(180 * self.score_pulse)
            pygame.draw.rect(panel_surf, (*COLOR_NEON_CYAN[:3], glow_alpha),
                           (0, 0, panel_w, panel_h), width=2, border_radius=10)
        else:
            pygame.draw.rect(panel_surf, (60, 40, 100, 80),
                           (0, 0, panel_w, panel_h), width=1, border_radius=10)
                           
        self.screen.blit(panel_surf, (panel_x, panel_y))
        score_label = self.font_score_label.render("SCORE", True, (100, 200, 220))
        self.screen.blit(score_label, (panel_x + 12, panel_y + 8))

        if self.score_pulse > 0.3:
            pulse_color = (
                min(255, COLOR_NEON_CYAN[0] + int(100 * self.score_pulse)),
                min(255, COLOR_NEON_CYAN[1] + int(50 * self.score_pulse)),
                min(255, COLOR_NEON_CYAN[2] + int(30 * self.score_pulse)),
            )
        else:
            pulse_color = COLOR_NEON_CYAN
            
        score_text = self.font_score.render(f"{self.score_display:07d}", True, pulse_color)
        self.screen.blit(score_text, (panel_x + 12, panel_y + 26))

        # 2. 키 가이드라인 
        hit_y, hit_w = self._get_projection(self.hit_line_progress)
        hit_x, _ = self._get_lane_x(0, hit_w)
        keys_str = ["A", "S", "D", "F"]
        key_y = int(hit_y + self.sh * 0.06)

        for lane in range(4):
            kx = int(hit_x + (lane + 0.5) * hit_w / 4)
            key_radius = int(min(hit_w / 4 * 0.25, 22))

            if self.key_glows[lane] > 0:
                pygame.draw.circle(self.screen, C_NOTE_COLORS[lane], (kx, key_y), key_radius)
                key_color = COLOR_WHITE
            else:
                pygame.draw.circle(self.screen, (30, 20, 60), (kx, key_y), key_radius)
                pygame.draw.circle(self.screen, (80, 60, 130), (kx, key_y), key_radius, 1)
                key_color = (120, 110, 160)

            key_surf = self.font_key.render(keys_str[lane], True, key_color)
            self.screen.blit(key_surf, key_surf.get_rect(center=(kx, key_y)))

        # 3. 중앙 콤보 / 판정 글씨 팝업
        for j in self.judgments:
            age = self.time - j["spawn_time"]
            ratio = age / j["duration"]

            anim_y = cy - int(self.sh * 0.12) - int(40 * ratio)

            if ratio < 0.15:
                scale = 1.0 + 0.8 * (1.0 - ratio / 0.15)
            elif ratio < 0.3:
                scale = 1.0 + 0.1 * math.sin((ratio - 0.15) / 0.15 * math.pi)
            else:
                scale = 1.0

            judge_surf = self.font_judge.render(j["text"], True, j["color"])

            alpha = int(255 * (1.0 - max(0, (ratio - 0.5)) * 2.0))
            alpha = max(0, min(255, alpha))
            judge_surf.set_alpha(alpha)

            if scale != 1.0:
                new_w = int(judge_surf.get_width() * scale)
                new_h = int(judge_surf.get_height() * scale)
                if new_w > 0 and new_h > 0:
                    judge_surf = pygame.transform.scale(judge_surf, (new_w, new_h))

            self.screen.blit(judge_surf, judge_surf.get_rect(center=(cx, anim_y)))

            combo_val = j.get("combo", 0)
            if combo_val > 0:
                sub_y = anim_y + int(self.sh * 0.055)
                sub_text = f"+{combo_val} COMBO"

                if combo_val >= 30:
                    sub_color = (255, 180, 0)
                elif combo_val >= 10:
                    sub_color = COLOR_NEON_CYAN
                else:
                    sub_color = (180, 180, 200)

                sub_surf = self.font_combo_label.render(sub_text, True, sub_color)
                sub_surf.set_alpha(alpha)
                self.screen.blit(sub_surf, sub_surf.get_rect(center=(cx, sub_y)))

    def _draw_countdown(self):
        """게임 시작 전 혹은 종료 후의 카운트다운을 화면에 그립니다."""
        if self.state == "PLAYING":
            return
            
        text = ""
        pulse = 1.0
        
        if self.state == "COUNTDOWN_START":
            if self.countdown_time > 1.0:
                text = str(int(self.countdown_time))
                pulse = self.countdown_time - int(self.countdown_time)
            elif self.countdown_time > 0:
                text = "START!"
                pulse = self.countdown_time
                
        elif self.state == "COUNTDOWN_END":
            if self.countdown_time > 0:
                text = str(int(self.countdown_time) + 1)
                pulse = self.countdown_time - int(self.countdown_time)
                
        if not text:
            return
            
        cx = self.sw // 2
        cy = self.sh // 2 - int(self.sh * 0.1)
        
        size_scale = 1.0 + (1.0 - pulse) * 1.5
        alpha = int(255 * pulse)
        
        base_surf = self.font_judge.render(text, True, COLOR_NEON_CYAN)
        scaled_w = int(base_surf.get_width() * size_scale)
        scaled_h = int(base_surf.get_height() * size_scale)
        
        if scaled_w > 0 and scaled_h > 0:
            scaled_surf = pygame.transform.smoothscale(base_surf, (scaled_w, scaled_h))
            
            alpha_surf = pygame.Surface((scaled_w, scaled_h), pygame.SRCALPHA)
            alpha_surf.blit(scaled_surf, (0, 0))
            alpha_surf.set_alpha(alpha)
            
            rect = alpha_surf.get_rect(center=(cx, cy))
            self.screen.blit(alpha_surf, rect)

    def draw(self):
        self._draw_track()
        self._draw_notes()
        self._draw_hit_particles()
        self._draw_ui()
        self._draw_countdown()
        self.screen.blit(self._scanline_surface, (0, 0))
