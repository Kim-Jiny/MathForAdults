#!/usr/bin/env python3
"""2차 검증 실패 문제 제거 + 수학Ⅱ 검증된 문제 보충."""
import json

BASE = 'assets/problems'

# 1) 2차 검증 실패 문제 제거
REMOVE = {
    'common.json': {'gen_common_16'},
    'math1.json': {'gen_math1_31'},
}
for fname, ids in REMOVE.items():
    path = f'{BASE}/{fname}'
    data = json.load(open(path))
    before = len(data)
    data = [p for p in data if p['id'] not in ids]
    json.dump(data, open(path, 'w'), ensure_ascii=False, indent=2)
    print(f'{fname}: {before} → {len(data)} (제거 {before-len(data)})')

# 2) 수학Ⅱ 보충 (직접 검산 완료)
M2_EXTRA = [
    {"id":"m2_x_001","subject":"수학Ⅱ","chapter":"함수의 극한과 연속","lesson":"함수의 극한",
     "difficulty":"대표 유형","question":"lim(x→1) (x³ − 1)/(x − 1) 의 값은?",
     "choices":["1","2","3","4"],"answerIndex":2,
     "explanation":"x³−1 = (x−1)(x²+x+1) 이므로 극한값은 1²+1+1 = 3.","detailedExplanation":None,"estimatedTime":"2분"},
    {"id":"m2_x_002","subject":"수학Ⅱ","chapter":"미분","lesson":"도함수의 활용",
     "difficulty":"대표 유형","question":"이차함수 f(x) = x² − 4x + 3 의 최솟값은?",
     "choices":["−1","0","1","3"],"answerIndex":0,
     "explanation":"f(x) = (x−2)² − 1 이므로 x = 2에서 최솟값 −1.","detailedExplanation":None,"estimatedTime":"2분"},
    {"id":"m2_x_003","subject":"수학Ⅱ","chapter":"미분","lesson":"미분계수와 도함수",
     "difficulty":"기본 유형","question":"f(x) = 2x² + 1 일 때, f′(3)의 값은?",
     "choices":["6","9","12","16"],"answerIndex":2,
     "explanation":"f′(x) = 4x 이므로 f′(3) = 12.","detailedExplanation":None,"estimatedTime":"1분"},
    {"id":"m2_x_004","subject":"수학Ⅱ","chapter":"적분","lesson":"정적분",
     "difficulty":"기본 유형","question":"∫₀³ x² dx 의 값은?",
     "choices":["3","6","9","27"],"answerIndex":2,
     "explanation":"[x³/3]₀³ = 27/3 = 9.","detailedExplanation":None,"estimatedTime":"1분"},
    {"id":"m2_x_005","subject":"수학Ⅱ","chapter":"적분","lesson":"정적분의 활용",
     "difficulty":"대표 유형","question":"곡선 y = 2x 와 x축, 두 직선 x = 1, x = 2 로 둘러싸인 부분의 넓이는?",
     "choices":["2","3","4","6"],"answerIndex":1,
     "explanation":"∫₁² 2x dx = [x²]₁² = 4 − 1 = 3.","detailedExplanation":None,"estimatedTime":"2분"},
]
path = f'{BASE}/math2.json'
data = json.load(open(path))
ids = {p['id'] for p in data}
added = [p for p in M2_EXTRA if p['id'] not in ids]
data += added
json.dump(data, open(path, 'w'), ensure_ascii=False, indent=2)
print(f'math2.json: 보충 {len(added)} → 총 {len(data)}')
