"""問題を短い書式で書き、assets/questions/<id>.json の形に変換する。

書き方:
    E = Exam('clf', 'CLF-C02')
    E.ref('s3-presign', '署名付き URL を使用したオブジェクトの共有', 'AmazonS3/latest/userguide/ShareObjectPreSignedURL.html')
    E.q('d1', '問題文', [('正解の選択肢', '理由'), ('誤り', '理由'), ...], [0],
        '全体の解説', ['s3-presign'], ev={'s3-presign': ['presigned URL']},
        drills=[tf('ポイント', '文', True, '理由'), mc('ポイント', '問い', [(...)], 0, 'まとめ')],
        group='xxx')

- 選択肢は「正解を先頭」など好きな順に書いてよい。単一選択の正解の位置は自動で A〜D に散らす
- ev は根拠ページ（英語版）に含まれるはずの語句。verify.py で照合する（JSON には出さない）
- url は docs.aws.amazon.com/ja_jp/ 以下のパス、または https:// から始まる完全な URL
"""
import json
import random

DOCS = 'https://docs.aws.amazon.com/ja_jp/'


class Drill:
    def __init__(self, kind, point, question, choices, answer, explanation, refs, ev):
        self.kind = kind
        self.point = point
        self.question = question
        self.choices = choices
        self.answer = answer
        self.explanation = explanation
        self.refs = refs
        self.ev = ev or {}


def tf(point, statement, is_true, why, summary=None, refs=None, ev=None):
    """○×の一問一答。why は正解の側の解説（「正しいです。」は自動で付ける）。summary を省くと why をまとめにも使う"""
    return Drill('tf', point, statement, why, 0 if is_true else 1, summary, refs, ev)


def mc(point, question, choices, answer, summary, refs=None, ev=None):
    """4択の一問一答。choices は (文, 解説) のリスト、answer は正解の添字"""
    return Drill('mc', point, question, choices, answer, summary, refs, ev)


class Exam:
    def __init__(self, exam_id, code):
        self.id = exam_id
        self.code = code
        self.refs = {}
        self.items = []  # (question dict, drills, ev)

    def ref(self, key, title, url):
        if key in self.refs:
            raise ValueError(f'ref の重複: {key}')
        full = url if url.startswith('http') else DOCS + url
        self.refs[key] = {'title': title, 'url': full}

    def q(self, domain, question, choices, answers, explanation, refs, ev=None,
          drills=(), group=None):
        for r in refs:
            if r not in self.refs:
                raise KeyError(f'未登録の ref: {r}')
        self.items.append({
            'domain': domain, 'question': question, 'choices': choices,
            'answers': list(answers), 'explanation': explanation, 'refs': refs,
            'ev': ev or {}, 'drills': list(drills), 'group': group,
        })

    # ---------- 変換 ----------

    def _place(self, choices, answers, target, rng):
        """単一選択の正解を target の位置に置き、ほかはシャッフルする"""
        correct = choices[answers[0]]
        others = [c for i, c in enumerate(choices) if i != answers[0]]
        rng.shuffle(others)
        others.insert(target, correct)
        return others, [target]

    def build(self):
        rng = random.Random(self.id)
        exam_q, drill_q = [], []
        single_slots = []  # 正解の位置を均等に回す
        drill_count = {0: 0, 1: 0, 2: 0, 3: 0}
        n = 0
        d = 0
        for item in self.items:
            n += 1
            qid = f'{self.id}-{n:03d}'
            choices = [{'text': t, 'explanation': e} for t, e in item['choices']]
            answers = item['answers']
            if len(answers) == 1:
                if not single_slots:
                    single_slots = [0, 1, 2, 3]
                    rng.shuffle(single_slots)
                choices, answers = self._place(choices, answers, single_slots.pop(), rng)
            q = {'id': qid, 'domain': item['domain'], 'question': item['question'],
                 'choices': choices, 'answers': answers,
                 'explanation': item['explanation'],
                 'references': [self.refs[r] for r in item['refs']]}
            if item['group']:
                q['group'] = item['group']
            exam_q.append(q)

            for dr in item['drills']:
                d += 1
                did = f'{self.id}-d{d:03d}'
                refs = dr.refs or item['refs']
                for r in refs:
                    if r not in self.refs:
                        raise KeyError(f'未登録の ref: {r}（{did}）')
                if dr.kind == 'tf':
                    ok = '正しいです。' + dr.choices
                    if dr.answer == 0:
                        ch = [{'text': '○ 正しい', 'explanation': ok},
                              {'text': '× 誤り', 'explanation': 'この文は正しいです（理由は ○ の解説を参照）。'}]
                    else:
                        ch = [{'text': '○ 正しい', 'explanation': 'この文は誤りです（理由は × の解説を参照）。'},
                              {'text': '× 誤り', 'explanation': ok}]
                    ans = [dr.answer]
                    # まとめを書いていない○×は、分解元の本番形式の問題の解説をまとめにする（正解の解説と同じ文の繰り返しを避ける）
                    summary = dr.explanation or item['explanation']
                else:
                    ch = [{'text': t, 'explanation': e} for t, e in dr.choices]
                    # ○×の正解（A か B）も含めて数え、これまでに正解が少ない位置に置く（A への偏りを防ぐ）
                    low = min(drill_count[i] for i in range(len(ch)))
                    cands = [i for i in range(len(ch)) if drill_count[i] == low]
                    ch, ans = self._place(ch, [dr.answer], rng.choice(cands), rng)
                    summary = dr.explanation
                drill_count[ans[0]] += 1
                drill_q.append({
                    'id': did, 'type': 'drill', 'domain': item['domain'],
                    'source': qid, 'point': dr.point, 'question': dr.question,
                    'choices': ch, 'answers': ans, 'explanation': summary,
                    'references': [self.refs[r] for r in refs]})
        return {'examId': self.id, 'examCode': self.code,
                'questions': exam_q + drill_q}

    def evidence(self):
        """照合用：(問題の番号, ref のキー, 語句のリスト)"""
        out = []
        for n, item in enumerate(self.items, 1):
            for key, phrases in item['ev'].items():
                out.append((f'{self.id}-{n:03d}', key, phrases))
            for dr in item['drills']:
                for key, phrases in dr.ev.items():
                    out.append((f'{self.id}-{n:03d}/{dr.point}', key, phrases))
        return out

    def write(self, path):
        data = self.build()
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        ex = [q for q in data['questions'] if q.get('type') != 'drill']
        dr = [q for q in data['questions'] if q.get('type') == 'drill']
        print(f'{self.id}: 本番形式 {len(ex)}問・一問一答 {len(dr)}問 → {path}')
