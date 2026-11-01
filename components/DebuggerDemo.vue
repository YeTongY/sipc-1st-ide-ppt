<script setup lang="ts">
import { useSlideContext } from '@slidev/client'
import { computed } from 'vue'

/**
 * 模拟 CLion 调试界面（对应 Example/loop_bug.c 第 27 ~ 56 行）
 * 每点击一次推进一个调试步骤，行号与变量呈现方式都跟 CLion 实际界面一致：
 *   - 断点设在第 34 行（循环体）—— 比设在 for 那一行可靠，原因见讲师备注
 *   - scores 是函数参数，类型退化为 const int *，CLion 只能展开 *scores 一个元素
 *   - 最后一步演示用强制类型转换的监视表达式把整个数组展开
 */

const { $clicks } = useSlideContext()

const LINE_H = 22
const VIEW_LINES = 15
const BREAK_LINE = 34
const SCORES = [92, 78, 85, 96, 64]
const EXPECTED_TOTAL = 415

interface CodeLine { n: number, html: string }

/* Example/loop_bug.c 第 27 ~ 56 行 */
const CODE: CodeLine[] = [
  { n: 27, html: '<span class="dbg-ty">static</span> <span class="dbg-ty">int</span> <span class="dbg-fn">sum_scores</span>(<span class="dbg-ty">const</span> <span class="dbg-ty">int</span> *scores, <span class="dbg-ty">int</span> count)' },
  { n: 28, html: '{' },
  { n: 29, html: '    <span class="dbg-ty">int</span> i;' },
  { n: 30, html: '    <span class="dbg-ty">int</span> total = <span class="dbg-num">0</span>;' },
  { n: 31, html: '' },
  { n: 32, html: '    <span class="dbg-cmt">/* 求总分：把每个成绩累加进 total */</span>' },
  { n: 33, html: '    <span class="dbg-kw">for</span> (i = <span class="dbg-num">0</span>; i &lt; count - <span class="dbg-num">1</span>; i++) {' },
  { n: 34, html: '        total += scores[i];   <span class="dbg-cmt">/* [断点 1] 在这一行设断点 */</span>' },
  { n: 35, html: '    }' },
  { n: 36, html: '    <span class="dbg-kw">return</span> total;' },
  { n: 37, html: '}' },
  { n: 38, html: '' },
  { n: 39, html: '<span class="dbg-ty">int</span> <span class="dbg-fn">main</span>(<span class="dbg-ty">void</span>)' },
  { n: 40, html: '{' },
  { n: 41, html: '    <span class="dbg-ty">int</span> i;' },
  { n: 42, html: '    <span class="dbg-ty">int</span> total;' },
  { n: 43, html: '    <span class="dbg-ty">double</span> average;' },
  { n: 44, html: '' },
  { n: 45, html: '    <span class="dbg-fn">printf</span>(<span class="dbg-str">"scores : "</span>);' },
  { n: 46, html: '    <span class="dbg-kw">for</span> (i = <span class="dbg-num">0</span>; i &lt; SCORE_COUNT; i++)' },
  { n: 47, html: '        <span class="dbg-fn">printf</span>(<span class="dbg-str">"%d "</span>, g_scores[i]);' },
  { n: 48, html: '    <span class="dbg-fn">printf</span>(<span class="dbg-str">"\\n"</span>);' },
  { n: 49, html: '' },
  { n: 50, html: '    total   = <span class="dbg-fn">sum_scores</span>(g_scores, SCORE_COUNT);' },
  { n: 51, html: '    average = (<span class="dbg-ty">double</span>)total / SCORE_COUNT;' },
  { n: 52, html: '' },
  { n: 53, html: '    <span class="dbg-fn">printf</span>(<span class="dbg-str">"\\n----- report -----\\n"</span>);' },
  { n: 54, html: '    <span class="dbg-fn">printf</span>(<span class="dbg-str">"total   = %d      (hand-calculated: 415)\\n"</span>, total);' },
  { n: 55, html: '    <span class="dbg-fn">printf</span>(<span class="dbg-str">"average = %.2f   (hand-calculated: 83.00)\\n"</span>, average);' },
  { n: 56, html: '    <span class="dbg-fn">printf</span>(<span class="dbg-str">"max     = %d      (hand-calculated: 96)\\n"</span>, <span class="dbg-fn">find_max</span>(g_scores, SCORE_COUNT));' },
]

const CONSOLE_HEAD = ['scores : 92 78 85 96 64 ']
const CONSOLE_FULL = [
  'scores : 92 78 85 96 64 ',
  '----- report -----',
  'total   = 351      (hand-calculated: 415)',
  'average = 70.20   (hand-calculated: 83.00)',
  'max     = 96      (hand-calculated: 96)',
]

interface Step {
  toolbar: 'play' | 'pause' | 'over' | 'into' | 'stop'
  line: number
  i: number
  total: number
  /* 已经真正被累加进 total 的元素个数 */
  reads: number
  changed: string[]
  stack: { fn: string, loc: string }[]
  console: string[]
  note: string
  watch: boolean
}

/* 第 0 帧为初始状态，之后每帧对应一次调试操作 */
const STEPS: Step[] = [
  {
    toolbar: 'play',
    line: 0,
    i: 0,
    total: 0,
    reads: 0,
    changed: [],
    stack: [],
    console: [],
    watch: false,
    note: '断点已设在第 34 行（循环体）—— 按 Shift+F9 以 Debug 方式启动',
  },
  {
    toolbar: 'over',
    line: 34,
    i: 0,
    total: 0,
    reads: 0,
    changed: [],
    stack: [{ fn: 'sum_scores', loc: 'loop_bug.c:34' }, { fn: 'main', loc: 'loop_bug.c:50' }],
    console: CONSOLE_HEAD,
    watch: false,
    note: '命中断点：i = 0、total = 0。注意 scores 的类型是 const int *，只有 *scores 一个元素',
  },
  {
    toolbar: 'over',
    line: 34,
    i: 1,
    total: 92,
    reads: 1,
    changed: ['total', 'i'],
    stack: [{ fn: 'sum_scores', loc: 'loop_bug.c:34' }, { fn: 'main', loc: 'loop_bug.c:50' }],
    console: CONSOLE_HEAD,
    watch: false,
    note: 'F8：执行 total += scores[0] 后回到循环体，i = 1、total = 92',
  },
  {
    toolbar: 'over',
    line: 34,
    i: 2,
    total: 170,
    reads: 2,
    changed: ['total', 'i'],
    stack: [{ fn: 'sum_scores', loc: 'loop_bug.c:34' }, { fn: 'main', loc: 'loop_bug.c:50' }],
    console: CONSOLE_HEAD,
    watch: false,
    note: 'F8：total += scores[1] → 170，i = 2',
  },
  {
    toolbar: 'over',
    line: 34,
    i: 3,
    total: 255,
    reads: 3,
    changed: ['total', 'i'],
    stack: [{ fn: 'sum_scores', loc: 'loop_bug.c:34' }, { fn: 'main', loc: 'loop_bug.c:50' }],
    console: CONSOLE_HEAD,
    watch: false,
    note: 'F8：total += scores[2] → 255，i = 3',
  },
  {
    toolbar: 'over',
    line: 36,
    i: 4,
    total: 351,
    reads: 4,
    changed: ['total', 'i'],
    stack: [{ fn: 'sum_scores', loc: 'loop_bug.c:36' }, { fn: 'main', loc: 'loop_bug.c:50' }],
    console: CONSOLE_HEAD,
    watch: false,
    note: 'F8：i 自增为 4，条件 i < 4 不再成立 → 跳出循环，第 5 个元素从未被累加',
  },
  {
    toolbar: 'play',
    line: 50,
    i: 4,
    total: 351,
    reads: 4,
    changed: [],
    stack: [{ fn: 'main', loc: 'loop_bug.c:50' }],
    console: CONSOLE_FULL,
    watch: false,
    note: 'F8 返回 main()：控制台打印 total = 351，与手工计算的 415 相差 64',
  },
  {
    toolbar: 'play',
    line: 50,
    i: 4,
    total: 351,
    reads: 4,
    changed: [],
    stack: [{ fn: 'main', loc: 'loop_bug.c:50' }],
    console: CONSOLE_FULL,
    watch: true,
    note: '加监视表达式 *(int(*)[5])scores（或 GDB 控制台 p *scores@count），数组就能展开了',
  },
]

const TOTAL_CLICKS = STEPS.length - 1

const step = computed(() => Math.min($clicks.value, STEPS.length - 1))
const frame = computed(() => STEPS[step.value])

const currentIndex = computed(() => {
  const n = frame.value.line
  return n ? CODE.findIndex(l => l.n === n) : -1
})

const highlightTop = computed(() => Math.max(0, currentIndex.value) * LINE_H)

const scrollTop = computed(() => {
  if (currentIndex.value < 0)
    return 0
  const max = Math.max(0, (CODE.length - VIEW_LINES) * LINE_H)
  const want = (currentIndex.value - Math.floor(VIEW_LINES / 2)) * LINE_H
  return Math.min(Math.max(0, want), max)
})

const toolbarButtons = [
  { key: 'play', label: 'F9', title: '继续' },
  { key: 'pause', label: '', title: '暂停' },
  { key: 'over', label: 'F8', title: '单步跳过' },
  { key: 'into', label: 'F7', title: '单步步入' },
  { key: 'stop', label: '', title: '停止' },
] as const

const isStarted = computed(() => step.value > 0)
</script>

<template>
  <div class="dbg-root">
    <!-- 注册分步点击：本页共 TOTAL_CLICKS 次点击，每次推进一帧 -->
    <span
      v-for="n in TOTAL_CLICKS"
      :key="`click-${n}`"
      v-click="n"
      class="dbg-click-marker"
    />

    <div class="dbg-window">
      <!-- 标题栏 + 调试工具条 -->
      <div class="dbg-titlebar">
        <span class="dbg-traffic" style="background:#ff5f57" />
        <span class="dbg-traffic" style="background:#febc2e" />
        <span class="dbg-traffic" style="background:#28c840" />
        <span class="dbg-filename">loop_bug.c</span>
        <span class="dbg-badge">CLion · 调试</span>
        <span class="dbg-clickhint">每点击一次推进一个调试步骤</span>

        <span class="dbg-spacer" />

        <span class="dbg-toolbar">
          <span
            v-for="b in toolbarButtons"
            :key="b.key"
            class="dbg-btn"
            :class="{ 'dbg-btn-active': frame.toolbar === b.key }"
            :title="b.title"
          >
            <svg viewBox="0 0 16 16" class="dbg-icon">
              <path v-if="b.key === 'play'" d="M5 3.2 L12.6 8 L5 12.8 Z" fill="currentColor" />
              <template v-else-if="b.key === 'pause'">
                <rect x="4.6" y="4" width="2.5" height="8" rx="0.6" fill="currentColor" />
                <rect x="8.9" y="4" width="2.5" height="8" rx="0.6" fill="currentColor" />
              </template>
              <template v-else-if="b.key === 'stop'">
                <rect x="4.6" y="4.6" width="6.8" height="6.8" rx="1.2" fill="currentColor" />
              </template>
              <template v-else-if="b.key === 'over'">
                <path d="M3.6 9.4 A4.9 4.9 0 0 1 12.2 7.6" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" />
                <path d="M12.4 7.4 L12.1 4.9 M12.4 7.4 L9.9 7.1" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" />
                <circle cx="8" cy="12.2" r="1.4" fill="currentColor" />
              </template>
              <template v-else>
                <path d="M8 3.2 V9" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" />
                <path d="M5.6 6.9 L8 9.3 L10.4 6.9" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" />
                <circle cx="8" cy="12.2" r="1.4" fill="currentColor" />
              </template>
            </svg>
            <span v-if="b.label" class="dbg-btn-label">{{ b.label }}</span>
          </span>
        </span>
      </div>

      <!-- 任务与累加进度：把「应该累加 5 个」与「实际累加了几个」摆在明面上 -->
      <div class="dbg-task">
        <span class="dbg-task-label">任务</span>
        <span class="dbg-task-text">5 个成绩求和，期望 <b>{{ EXPECTED_TOTAL }}</b></span>
        <span class="dbg-task-sep" />
        <span class="dbg-tchips">
          <span
            v-for="(sc, si) in SCORES"
            :key="si"
            class="dbg-tchip"
            :class="{
              'dbg-tchip-read': si < frame.reads,
              'dbg-tchip-miss': step >= 5 && si === 4,
              'dbg-tchip-flash': si === frame.reads - 1 && frame.changed.includes('total'),
            }"
          >
            <span class="dbg-tchip-idx">{{ si }}</span>{{ sc }}
            <span class="dbg-tchip-mark">{{ si < frame.reads ? '✓' : (step >= 5 && si === 4 ? '✗' : '') }}</span>
          </span>
        </span>
        <span class="dbg-spacer" />
        <span class="dbg-task-count">
          已累加 <b>{{ frame.reads }}</b> / {{ SCORES.length }} · total = <b>{{ frame.total }}</b>
        </span>
        <span v-if="step >= 5" class="dbg-task-gap">少累加 1 个元素 → {{ frame.total }} ≠ {{ EXPECTED_TOTAL }}</span>
      </div>

      <div class="dbg-body">
        <!-- 代码编辑区 -->
        <div class="dbg-editor">
          <div class="dbg-viewport">
            <div class="dbg-code" :style="{ transform: `translateY(${-scrollTop}px)` }">
              <div
                v-show="frame.line"
                class="dbg-highlight"
                :style="{ height: `${LINE_H}px`, transform: `translateY(${highlightTop}px)` }"
              />
              <div
                v-show="frame.line"
                class="dbg-arrow"
                :style="{ height: `${LINE_H}px`, transform: `translateY(${highlightTop}px)` }"
              >
                ▶
              </div>
              <div
                v-for="(l, idx) in CODE"
                :key="l.n"
                class="dbg-line"
                :class="{ 'dbg-line-current': idx === currentIndex && frame.line }"
                :style="{ height: `${LINE_H}px` }"
              >
                <span class="dbg-gutter">
                  <span v-if="l.n === BREAK_LINE" class="dbg-breakpoint" :class="{ 'dbg-breakpoint-hit': isStarted }" />
                  {{ l.n }}
                </span>
                <span class="dbg-text" v-html="l.html" />
              </div>
            </div>
          </div>
        </div>

        <!-- 右侧调试面板（按 CLion「线程和变量」的写法） -->
        <div class="dbg-panels">
          <div class="dbg-panel">
            <div class="dbg-panel-title">线程和变量</div>
            <template v-if="isStarted">
              <div class="dbg-var">
                <span class="dbg-caret">▾</span>
                <span class="dbg-var-name">scores</span>
                <span class="dbg-var-type">= {const int *}</span>
                <span class="dbg-addr">0x555555556010</span>
              </div>
              <div class="dbg-var dbg-sub">
                <span class="dbg-caret" />
                <span class="dbg-var-name">*scores</span>
                <span class="dbg-var-type">= {const int}</span>
                <span class="dbg-var-value">92</span>
              </div>
              <div class="dbg-var">
                <span class="dbg-caret" />
                <span class="dbg-var-name">count</span>
                <span class="dbg-var-type">= {int}</span>
                <span class="dbg-var-value">5</span>
              </div>
              <div class="dbg-var">
                <span class="dbg-caret" />
                <span class="dbg-var-name">i</span>
                <span class="dbg-var-type">= {int}</span>
                <span :key="`i-${step}`" class="dbg-var-value" :class="{ 'dbg-flash': frame.changed.includes('i') }">{{ frame.i }}</span>
              </div>
              <div class="dbg-var">
                <span class="dbg-caret" />
                <span class="dbg-var-name">total</span>
                <span class="dbg-var-type">= {int}</span>
                <span :key="`t-${step}`" class="dbg-var-value" :class="{ 'dbg-flash': frame.changed.includes('total') }">{{ frame.total }}</span>
              </div>
              <div class="dbg-hint">scores 是参数 → 类型退化为指针，看不到 5 个元素</div>
            </template>
            <div v-else class="dbg-empty">未启动调试</div>
          </div>

          <div v-if="frame.watch" class="dbg-panel dbg-panel-watch">
            <div class="dbg-panel-title">实时监视</div>
            <div class="dbg-var">
              <span class="dbg-caret">▾</span>
              <span class="dbg-watch-exp">*(int(*)[5])scores</span>
              <span class="dbg-var-type">= {const int[5]}</span>
            </div>
            <div class="dbg-array">
              <span
                v-for="(s, si) in SCORES"
                :key="si"
                class="dbg-cell"
                :class="{ 'dbg-cell-read': true, 'dbg-cell-miss': si === 4 }"
              >
                <span class="dbg-cell-idx">[{{ si }}]</span>
                <span class="dbg-cell-val">{{ s }}</span>
              </span>
            </div>
            <div class="dbg-hint dbg-hint-red">scores[4] = 64 从未被读取 —— 缺陷在这里现形</div>
          </div>

          <div class="dbg-panel">
            <div class="dbg-panel-title">调用栈</div>
            <template v-if="frame.stack.length">
              <div
                v-for="(f, fi) in frame.stack"
                :key="f.fn"
                class="dbg-frame"
                :class="{ 'dbg-frame-top': fi === 0 }"
              >
                <span class="dbg-frame-fn">{{ f.fn }}</span>
                <span class="dbg-frame-loc">{{ f.loc }}</span>
              </div>
            </template>
            <div v-else class="dbg-empty">—</div>
          </div>

          <div class="dbg-panel dbg-panel-console">
            <div class="dbg-panel-title">控制台</div>
            <div class="dbg-console">
              <template v-if="frame.console.length">
                <TransitionGroup name="dbg-line">
                  <div v-for="(c, ci) in frame.console" :key="ci" class="dbg-console-line">
                    {{ c || '\u00A0' }}
                  </div>
                </TransitionGroup>
              </template>
              <div v-else class="dbg-empty">程序未运行</div>
            </div>
          </div>
        </div>
      </div>

      <!-- 步骤提示条 -->
      <div class="dbg-status">
        <span class="dbg-step-badge">
          {{ step === 0 ? '就绪' : `STEP ${step} / ${TOTAL_CLICKS}` }}
        </span>
        <Transition name="dbg-note" mode="out-in">
          <span :key="step" class="dbg-note">{{ frame.note }}</span>
        </Transition>
        <span class="dbg-dots">
          <span
            v-for="n in STEPS.length"
            :key="n"
            class="dbg-dot"
            :class="{ 'dbg-dot-on': n - 1 <= step }"
          />
        </span>
      </div>
    </div>
  </div>
</template>

<style>
.dbg-root {
  width: 100%;
  font-family: 'Fira Code', ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
}

.dbg-click-marker {
  position: absolute;
  width: 0;
  height: 0;
  overflow: hidden;
}

.dbg-window {
  border: 1px solid #d0d7de;
  border-radius: 10px;
  overflow: hidden;
  background: #ffffff;
  box-shadow: 0 6px 18px rgba(15, 23, 42, 0.08);
}

/* ---------- 标题栏 ---------- */
.dbg-titlebar {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 32px;
  padding: 0 10px;
  background: #f6f8fa;
  border-bottom: 1px solid #d0d7de;
}

.dbg-traffic {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  display: inline-block;
}

.dbg-filename {
  margin-left: 6px;
  font-size: 12px;
  color: #57606a;
}

.dbg-badge {
  font-size: 9px;
  letter-spacing: 0.08em;
  padding: 1px 5px;
  border-radius: 4px;
  background: #dbeafe;
  color: #1d4ed8;
  font-weight: 700;
}

.dbg-spacer { flex: 1; }

.dbg-toolbar {
  display: flex;
  align-items: center;
  gap: 3px;
}

.dbg-btn {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  padding: 2px 5px;
  border-radius: 4px;
  color: #57606a;
  transition: all 200ms ease;
}

.dbg-btn-active {
  background: #dbeafe;
  color: #1d4ed8;
  box-shadow: inset 0 0 0 1px #93c5fd;
}

.dbg-icon {
  width: 14px;
  height: 14px;
}

.dbg-btn-label {
  font-size: 8px;
  font-weight: 700;
  opacity: 0.75;
}

/* ---------- 任务与进度条 ---------- */
.dbg-clickhint {
  font-size: 9.5px;
  color: #8b949e;
  font-family: 'Nunito Sans', system-ui, sans-serif;
}

.dbg-task {
  display: flex;
  align-items: center;
  gap: 7px;
  height: 30px;
  padding: 0 10px;
  background: #fbfdff;
  border-bottom: 1px solid #d0d7de;
  font-size: 10px;
  color: #57606a;
}

.dbg-task-label {
  font-size: 9px;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 4px;
  background: #dbeafe;
  color: #1d4ed8;
}

.dbg-task-text b, .dbg-task-count b { color: #24292f; }

.dbg-task-sep { width: 1px; height: 14px; background: #d0d7de; }

.dbg-tchips { display: inline-flex; align-items: center; gap: 4px; }

.dbg-tchip {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 1px 5px;
  border-radius: 4px;
  background: #eaeef2;
  color: #8b949e;
  transition: background 250ms ease, color 250ms ease;
}

.dbg-tchip-idx { font-size: 8px; opacity: 0.55; }
.dbg-tchip-mark { font-size: 9px; font-weight: 700; }

.dbg-tchip-read { background: #dbeafe; color: #1e40af; font-weight: 600; }

.dbg-tchip-miss {
  background: #fee2e2;
  color: #b91c1c;
  font-weight: 600;
  box-shadow: 0 0 0 1px #fca5a5;
}

.dbg-tchip-flash { animation: dbg-flash 800ms ease-out; }

.dbg-task-count { white-space: nowrap; }

.dbg-task-gap { color: #b91c1c; font-weight: 600; white-space: nowrap; }

/* ---------- 主体 ---------- */
.dbg-body {
  display: flex;
  align-items: stretch;
  /* 高度写死，保证每一步（含最后多出来的「实时监视」面板）都不会撑出画面 */
  height: 330px;
}

.dbg-editor {
  flex: 1 1 55%;
  min-width: 0;
  height: 100%;
  background: #ffffff;
  border-right: 1px solid #d0d7de;
}

.dbg-viewport {
  height: 100%;
  overflow: hidden;
  position: relative;
  /* 长行像真实 IDE 一样被裁掉，右边缘做渐隐，避免出现生硬的截断 */
  mask-image: linear-gradient(to right, #000 calc(100% - 28px), transparent 100%);
  -webkit-mask-image: linear-gradient(to right, #000 calc(100% - 28px), transparent 100%);
}

.dbg-code {
  position: relative;
  transition: transform 260ms cubic-bezier(0.2, 0.8, 0.2, 1);
  padding: 4px 0;
}

.dbg-highlight {
  position: absolute;
  left: 0;
  right: 0;
  top: 4px;
  background: rgba(59, 130, 246, 0.13);
  border-left: 2px solid #3b82f6;
  transition: transform 220ms cubic-bezier(0.2, 0.8, 0.2, 1);
}

.dbg-arrow {
  position: absolute;
  left: 4px;
  top: 4px;
  width: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 9px;
  color: #eab308;
  transition: transform 220ms cubic-bezier(0.2, 0.8, 0.2, 1);
}

.dbg-line {
  display: flex;
  align-items: center;
  font-size: 11px;
  line-height: 1;
  white-space: pre;
}

.dbg-gutter {
  position: relative;
  flex: 0 0 62px;
  text-align: right;
  padding-right: 8px;
  color: #8b949e;
  font-size: 11px;
  user-select: none;
}

.dbg-breakpoint {
  position: absolute;
  left: 22px;
  top: 50%;
  transform: translateY(-50%);
  width: 9px;
  height: 9px;
  border-radius: 50%;
  background: #ef4444;
  box-shadow: 0 0 0 1px rgba(239, 68, 68, 0.35);
}

.dbg-breakpoint-hit {
  animation: dbg-pulse 1.6s ease-out infinite;
}

@keyframes dbg-pulse {
  0% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0.5); }
  70% { box-shadow: 0 0 0 7px rgba(239, 68, 68, 0); }
  100% { box-shadow: 0 0 0 0 rgba(239, 68, 68, 0); }
}

.dbg-text { color: #24292f; }

.dbg-kw { color: #cf222e; }
.dbg-ty { color: #0550ae; }
.dbg-fn { color: #8250df; }
.dbg-num { color: #0a3069; }
.dbg-str { color: #0a3069; }
.dbg-cmt { color: #6e7781; font-style: italic; }

.dbg-line-current .dbg-text { font-weight: 600; }

/* ---------- 右侧面板 ---------- */
.dbg-panels {
  flex: 1 1 45%;
  min-width: 0;
  height: 100%;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 1px;
  background: #d0d7de;
}

.dbg-panel {
  background: #f6f8fa;
  padding: 4px 8px;
}

.dbg-panel-console { flex: 1; min-height: 0; overflow: hidden; }

.dbg-panel-title {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.1em;
  color: #8b949e;
  margin-bottom: 3px;
}

.dbg-var {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 11.5px;
  line-height: 16px;
}

.dbg-sub { padding-left: 14px; }

.dbg-var-name { color: #0550ae; }
.dbg-var-type { color: #8b949e; font-size: 10px; }
.dbg-addr { color: #6e7781; font-size: 10.5px; }
.dbg-caret { color: #8b949e; font-size: 9px; width: 9px; display: inline-block; }

.dbg-var-value {
  color: #24292f;
  border-radius: 3px;
  padding: 0 3px;
}

.dbg-flash { animation: dbg-flash 800ms ease-out; }

@keyframes dbg-flash {
  0% { background: #f59e0b; color: #ffffff; }
  100% { background: transparent; }
}

.dbg-hint {
  margin-top: 3px;
  font-size: 9.5px;
  line-height: 12px;
  color: #8b949e;
}

.dbg-hint-red { color: #b91c1c; }

.dbg-mono { font-family: inherit; color: #57606a; }

.dbg-watch-exp { color: #8250df; }

.dbg-array {
  display: flex;
  flex-wrap: wrap;
  gap: 3px;
  margin: 2px 0 0 14px;
}

.dbg-cell {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 0 4px;
  border-radius: 3px;
  font-size: 10px;
  background: #eaeef2;
  color: #6e7781;
  transition: all 250ms ease;
}

.dbg-cell-idx { opacity: 0.6; }

.dbg-cell-read { background: #dbeafe; color: #1e40af; }

.dbg-cell-miss {
  background: #fee2e2;
  color: #b91c1c;
  box-shadow: 0 0 0 1px #fca5a5;
}

.dbg-frame {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  font-size: 11px;
  line-height: 16px;
  padding: 0 4px;
  border-radius: 3px;
  color: #57606a;
}

.dbg-frame-top {
  background: #dbeafe;
  color: #1e40af;
  font-weight: 600;
}

.dbg-frame-loc { font-size: 10px; opacity: 0.75; }

.dbg-console { font-size: 9.5px; line-height: 12px; color: #24292f; }
.dbg-console-line { white-space: pre; }

.dbg-empty { font-size: 10px; color: #b1b8c0; }

/* ---------- 底部提示条 ---------- */
.dbg-status {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 38px;
  padding: 0 10px;
  background: #f6f8fa;
  border-top: 1px solid #d0d7de;
}

.dbg-step-badge {
  flex: 0 0 auto;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.06em;
  padding: 2px 6px;
  border-radius: 4px;
  background: #dbeafe;
  color: #1d4ed8;
}

.dbg-note {
  flex: 1;
  font-size: 11px;
  color: #24292f;
  font-family: 'Nunito Sans', system-ui, sans-serif;
}

.dbg-dots { display: flex; gap: 3px; }

.dbg-dot {
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: #d0d7de;
  transition: background 200ms ease;
}

.dbg-dot-on { background: #3b82f6; }

.dbg-note-enter-active, .dbg-note-leave-active { transition: opacity 180ms ease, transform 180ms ease; }
.dbg-note-enter-from { opacity: 0; transform: translateY(4px); }
.dbg-note-leave-to { opacity: 0; transform: translateY(-4px); }

.dbg-line-enter-active { transition: opacity 260ms ease, transform 260ms ease; }
.dbg-line-enter-from { opacity: 0; transform: translateY(4px); }

/* ---------- 暗色模式 ---------- */
.dark .dbg-window { background: #1e1e1e; border-color: #3c3c3c; box-shadow: none; }
.dark .dbg-titlebar,
.dark .dbg-status { background: #252526; border-color: #3c3c3c; }
.dark .dbg-filename, .dark .dbg-btn { color: #cccccc; }
.dark .dbg-badge, .dark .dbg-step-badge { background: #1e3a8a; color: #bfdbfe; }
.dark .dbg-btn-active { background: #1e3a8a; color: #bfdbfe; box-shadow: inset 0 0 0 1px #3b82f6; }
.dark .dbg-editor { background: #1e1e1e; border-color: #3c3c3c; }
.dark .dbg-text { color: #d4d4d4; }
.dark .dbg-gutter { color: #858585; }
.dark .dbg-kw { color: #c586c0; }
.dark .dbg-ty { color: #4ec9b0; }
.dark .dbg-fn { color: #dcdcaa; }
.dark .dbg-num { color: #b5cea8; }
.dark .dbg-str { color: #ce9178; }
.dark .dbg-cmt { color: #6a9955; }
.dark .dbg-highlight { background: rgba(59, 130, 246, 0.22); }
.dark .dbg-panels { background: #3c3c3c; }
.dark .dbg-panel { background: #252526; }
.dark .dbg-panel-title { color: #858585; }
.dark .dbg-var-name { color: #4ec9b0; }
.dark .dbg-var-value, .dark .dbg-console, .dark .dbg-note { color: #d4d4d4; }
.dark .dbg-var-type, .dark .dbg-frame, .dark .dbg-addr { color: #9d9d9d; }
.dark .dbg-hint { color: #858585; }
.dark .dbg-hint-red { color: #fca5a5; }
.dark .dbg-watch-exp { color: #dcdcaa; }
.dark .dbg-cell { background: #37373d; color: #9d9d9d; }
.dark .dbg-cell-read { background: #1e3a8a; color: #bfdbfe; }
.dark .dbg-cell-miss { background: #4c1d1d; color: #fca5a5; box-shadow: 0 0 0 1px #7f1d1d; }
.dark .dbg-frame-top { background: #1e3a8a; color: #bfdbfe; }
.dark .dbg-dot { background: #3c3c3c; }
.dark .dbg-dot-on { background: #60a5fa; }
.dark .dbg-empty { color: #6b6b6b; }
.dark .dbg-clickhint { color: #858585; }
.dark .dbg-task { background: #1e1e1e; border-color: #3c3c3c; color: #9d9d9d; }
.dark .dbg-task-label { background: #1e3a8a; color: #bfdbfe; }
.dark .dbg-task-text b, .dark .dbg-task-count b { color: #d4d4d4; }
.dark .dbg-task-sep { background: #3c3c3c; }
.dark .dbg-tchip { background: #37373d; color: #9d9d9d; }
.dark .dbg-tchip-read { background: #1e3a8a; color: #bfdbfe; }
.dark .dbg-tchip-miss { background: #4c1d1d; color: #fca5a5; box-shadow: 0 0 0 1px #7f1d1d; }
.dark .dbg-task-gap { color: #fca5a5; }
</style>
