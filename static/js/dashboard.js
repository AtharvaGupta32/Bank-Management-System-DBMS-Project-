/**
 * dashboard.js — Frontend Controller for Nola. Dark-Mode Fintech UI
 * Target Database: Oracle Database (BACSE202)
 *
 * Handles:
 * 1. Live Overview Bento Grid loading and real-time Chart.js spline rendering
 * 2. Customer Switcher (10 seeded customers)
 * 3. 4 Teammate Viva Modules (DML operations & 20 labeled SELECT queries)
 * 4. PL/SQL & Cursor Lab (2 Procedures, 2 Functions, 1 Cursor, 2 Triggers)
 * 5. Collapsible Live Oracle Execution Inspector (5-Step Trace)
 * 6. Fund Transfer & EMI Modals with Min-Balance Breach Trigger Testbed
 */

// ─────────────────────────────────────────────────────────────────────────────
// Global State
// ─────────────────────────────────────────────────────────────────────────────
let currentCustomerId = 1001;
let currentOverviewData = null;
let isAccountMasked = true;
let isBalanceVisible = true;
let splineChart = null;
let selectedTransferMode = 'UPI';
let isFlowDrawerOpen = false;
let lastExecutedSql = '-- No SQL executed yet';

// ─────────────────────────────────────────────────────────────────────────────
// Currency and Data Formatters
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Format numbers as Indian Rupees (₹) with en-IN locale
 */
function formatINR(amount) {
  if (amount === null || amount === undefined || isNaN(amount)) {
    return '₹0.00';
  }
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount);
}

/**
 * Mask account number: e.g. 10042011 -> •••• ••2011
 */
function maskAccountNumber(accNo) {
  if (!accNo) return '•••• ••••';
  const str = String(accNo);
  if (str.length <= 4) return '•••• ' + str;
  return '•••• ••' + str.slice(-4);
}

/**
 * Extract 2-letter initials from full name
 */
function getInitials(name) {
  if (!name) return 'NB';
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

/**
 * Toast Notification System
 */
function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  if (!container) return;

  const toast = document.createElement('div');
  const bgStyles = {
    success: 'bg-[#12261F] border-emerald-500/40 text-emerald-300',
    error: 'bg-[#2A1818] border-red-500/40 text-red-300',
    info: 'bg-[#111916] border-border-card text-gray-200',
    warning: 'bg-[#2A2318] border-amber-500/40 text-amber-300'
  }[type] || 'bg-[#111916] border-border-card text-gray-200';

  const iconName = {
    success: 'check-circle-2',
    error: 'alert-circle',
    info: 'info',
    warning: 'alert-triangle'
  }[type] || 'info';

  toast.className = `pointer-events-auto flex items-center gap-2.5 px-4 py-3 rounded-xl border ${bgStyles} text-xs font-medium shadow-xl backdrop-blur-md transition-all duration-300 transform translate-y-2 opacity-0 font-mono`;
  toast.innerHTML = `
    <i data-lucide="${iconName}" class="w-4 h-4 shrink-0"></i>
    <span class="truncate max-w-sm">${message}</span>
  `;

  container.appendChild(toast);
  lucide.createIcons({ root: toast });

  // Animate in
  requestAnimationFrame(() => {
    toast.classList.remove('translate-y-2', 'opacity-0');
  });

  // Auto remove after 4.5s
  setTimeout(() => {
    toast.classList.add('opacity-0', 'translate-y-2');
    setTimeout(() => toast.remove(), 300);
  }, 4500);
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Oracle Execution Inspector (5-Step Trace)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Update the bottom execution terminal with the professor-mandated 5-step flow:
 * 1. User Operation -> 2. SQL/PL/SQL Component -> 3. Tables Involved ->
 * 4. Database Effect -> 5. Execution Time & Result
 */
function updateExecutionTrace(trace, isSuccess = true, errorMsg = null) {
  if (!trace) return;

  const step1 = document.getElementById('flow-step-1');
  const step2 = document.getElementById('flow-step-2');
  const step3 = document.getElementById('flow-step-3');
  const step4 = document.getElementById('flow-step-4');
  const step5 = document.getElementById('flow-step-5');
  const rawSql = document.getElementById('flow-raw-sql');
  const badgeSummary = document.getElementById('terminal-badge-summary');
  const lastMs = document.getElementById('terminal-last-ms');

  // Step 1: User Operation
  if (step1) step1.textContent = trace.user_operation || 'Operation Executed';

  // Step 2: Component Type
  if (step2) step2.textContent = trace.component_type || 'SQL Statement';

  // Step 3: Tables Involved
  if (step3) {
    step3.innerHTML = '';
    const tables = Array.isArray(trace.tables_involved)
      ? trace.tables_involved
      : [trace.tables_involved];

    if (tables.length === 0 || !tables[0]) {
      step3.innerHTML = '<span class="text-xs text-gray-500">None</span>';
    } else {
      tables.forEach(t => {
        const badge = document.createElement('span');
        badge.className = 'px-1.5 py-0.5 rounded text-[10px] font-mono bg-card border border-border-card text-emerald-400 font-semibold';
        badge.textContent = t;
        step3.appendChild(badge);
      });
    }
  }

  // Step 4: Database Effect
  if (step4) {
    if (!isSuccess && errorMsg) {
      step4.textContent = `BLOCKED: ${errorMsg}`;
      step4.className = 'text-xs text-red-400 font-semibold mt-1 truncate';
    } else {
      step4.textContent = trace.effect || 'Committed to Oracle';
      step4.className = 'text-xs text-gray-300 mt-1 truncate';
    }
  }

  // Step 5: Execution Time & Status
  const ms = trace.execution_ms !== undefined ? `${trace.execution_ms} ms` : '0.00 ms';
  if (step5) {
    if (isSuccess) {
      step5.innerHTML = `<span class="text-emerald-400 font-mono">${ms}</span> • <span class="text-emerald-300 font-bold">COMMITTED</span>`;
    } else {
      step5.innerHTML = `<span class="text-red-400 font-mono">${ms}</span> • <span class="text-red-400 font-bold">ROLLED BACK</span>`;
    }
  }

  // Summary bar on collapsed footer
  if (badgeSummary) {
    if (isSuccess) {
      badgeSummary.textContent = `${trace.user_operation} • [${trace.component_type}]`;
      badgeSummary.className = 'hidden sm:inline-block text-[11px] font-mono text-emerald-400 truncate max-w-md';
    } else {
      badgeSummary.textContent = `Trigger/Oracle Rejected: ${trace.user_operation}`;
      badgeSummary.className = 'hidden sm:inline-block text-[11px] font-mono text-red-400 truncate max-w-md font-bold';
    }
  }

  if (lastMs) {
    lastMs.textContent = ms;
    lastMs.className = isSuccess ? 'text-emerald-400 font-mono font-bold' : 'text-red-400 font-mono font-bold';
  }

  // Raw SQL / PL/SQL
  lastExecutedSql = trace.sql_executed || '-- No SQL returned';
  if (rawSql) {
    rawSql.textContent = lastExecutedSql;
  }
}

/**
 * Toggle expanding/collapsing the bottom inspector
 */
function toggleFlowDrawer() {
  const body = document.getElementById('flow-drawer-body');
  const icon = document.getElementById('terminal-toggle-icon');
  if (!body) return;

  isFlowDrawerOpen = !isFlowDrawerOpen;
  if (isFlowDrawerOpen) {
    body.classList.remove('hidden');
    if (icon) icon.setAttribute('data-lucide', 'chevron-down');
  } else {
    body.classList.add('hidden');
    if (icon) icon.setAttribute('data-lucide', 'chevron-up');
  }
  lucide.createIcons({ root: document.getElementById('flow-drawer') });
}

function copyExecutedSql() {
  navigator.clipboard.writeText(lastExecutedSql).then(() => {
    const textEl = document.getElementById('copy-sql-text');
    if (textEl) {
      const orig = textEl.textContent;
      textEl.textContent = 'Copied!';
      setTimeout(() => { textEl.textContent = orig; }, 2000);
    }
    showToast('Oracle SQL copied to clipboard', 'info');
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation & Tab Switching
// ─────────────────────────────────────────────────────────────────────────────

function switchTab(tabId) {
  // Hide all view containers
  const views = ['overview', 'mod1', 'mod2', 'mod3', 'mod4', 'plsql'];
  views.forEach(v => {
    const el = document.getElementById(`view-${v}`);
    if (el) el.classList.add('hidden');

    const tabBtn = document.getElementById(`nav-tab-${v}`);
    if (tabBtn) {
      tabBtn.classList.remove('bg-sidebar-active', 'text-emerald-accent', 'shadow-inner');
      tabBtn.classList.add('text-gray-400', 'hover:text-gray-200', 'hover:bg-[#111916]');
    }
  });

  // Show target view
  const targetView = document.getElementById(`view-${tabId}`);
  if (targetView) targetView.classList.remove('hidden');

  const activeBtn = document.getElementById(`nav-tab-${tabId}`);
  if (activeBtn) {
    activeBtn.classList.remove('text-gray-400', 'hover:text-gray-200', 'hover:bg-[#111916]');
    activeBtn.classList.add('bg-sidebar-active', 'text-emerald-accent', 'shadow-inner');
  }

  // Refresh icons
  lucide.createIcons();
}

// ─────────────────────────────────────────────────────────────────────────────
// View 1: Overview Bento Grid Loader & Chart Renderer
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Fetch and populate complete Bento Grid for given customer ID
 */
async function loadCustomerOverview(customerId) {
  try {
    const res = await fetch(`/api/overview/${customerId}`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    currentOverviewData = data;

    renderProfile(data.profile);
    renderTotalBalance(data.total_balance);
    renderAccountDetails(data.accounts, data.profile);
    renderRecentTransactions(data.recent_txns);
    renderCashFlow(data.cashflow);
    renderLoansAndFds(data.loans, data.fixed_deposits);
    renderSplineChart(data.trend);

    // Populate modal dropdowns for this customer
    populateTransferModalOptions(data.accounts, data.beneficiaries);
    populateEmiModalOptions(data.loans);

    // Update Live Inspector trace with the profile trace
    if (data.traces && data.traces.profile) {
      updateExecutionTrace(data.traces.profile, true);
    }
  } catch (err) {
    console.error('Failed to load customer overview:', err);
    showToast(`Error fetching Oracle overview: ${err.message}`, 'error');
  }
}

/**
 * Render customer profile in top bar and left sidebar
 */
function renderProfile(profile) {
  if (!profile) return;
  const fullName = profile.full_name || 'Customer';
  const firstName = fullName.split(' ')[0] || 'Customer';
  const email = profile.email || 'customer@email.com';
  const initials = getInitials(fullName);

  // Top header greeting
  const greetingEl = document.getElementById('top-greeting');
  if (greetingEl) {
    const hour = new Date().getHours();
    const timeGreeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    greetingEl.textContent = `${timeGreeting}, ${firstName}`;
  }

  // Left sidebar profile card
  const avatarEl = document.getElementById('profile-avatar');
  if (avatarEl) avatarEl.textContent = initials;

  const nameEl = document.getElementById('profile-name');
  if (nameEl) nameEl.textContent = fullName;

  const emailEl = document.getElementById('profile-email');
  if (emailEl) emailEl.textContent = email;
}

/**
 * Render Total Balance card
 */
function renderTotalBalance(balance) {
  const el = document.getElementById('overview-total-balance');
  if (!el) return;
  el.textContent = isBalanceVisible ? formatINR(balance) : '₹••••••••';
}

function toggleBalanceVisibility() {
  isBalanceVisible = !isBalanceVisible;
  const icon = document.getElementById('balance-eye-icon');
  if (icon) {
    icon.setAttribute('data-lucide', isBalanceVisible ? 'eye' : 'eye-off');
    lucide.createIcons({ root: icon.parentElement });
  }
  if (currentOverviewData) {
    renderTotalBalance(currentOverviewData.total_balance);
  }
}

/**
 * Render Account Details Bento card
 */
function renderAccountDetails(accounts, profile) {
  if (!accounts || accounts.length === 0) return;
  const primary = accounts[0];

  const accNoEl = document.getElementById('account-no-display');
  if (accNoEl) {
    accNoEl.textContent = isAccountMasked ? maskAccountNumber(primary.account_no) : String(primary.account_no);
  }

  const typeEl = document.getElementById('meta-acc-type');
  if (typeEl) typeEl.textContent = primary.account_type || 'Savings';

  const ifscEl = document.getElementById('meta-ifsc');
  if (ifscEl) ifscEl.textContent = primary.ifsc_code || 'NOLA0000101';

  const branchEl = document.getElementById('meta-branch');
  if (branchEl) branchEl.textContent = primary.branch_name || 'Vellore Main';

  const openedEl = document.getElementById('meta-opened');
  if (openedEl) openedEl.textContent = primary.open_date || '--';

  const ageEl = document.getElementById('meta-age');
  if (ageEl) ageEl.textContent = profile && profile.age ? `${profile.age} yrs` : '24 yrs';

  const statusBadge = document.getElementById('account-status-badge');
  if (statusBadge) {
    const isActive = (primary.status || 'Active').toLowerCase() === 'active';
    statusBadge.innerHTML = `
      <span class="w-1.5 h-1.5 rounded-full ${isActive ? 'bg-emerald-400 status-pulse' : 'bg-red-400'}"></span>
      ${(primary.status || 'ACTIVE').toUpperCase()}
    `;
  }
}

function toggleAccountMask() {
  isAccountMasked = !isAccountMasked;
  const icon = document.getElementById('acc-mask-icon');
  if (icon) {
    icon.setAttribute('data-lucide', isAccountMasked ? 'eye' : 'eye-off');
    lucide.createIcons({ root: icon.parentElement });
  }
  if (currentOverviewData && currentOverviewData.accounts) {
    renderAccountDetails(currentOverviewData.accounts, currentOverviewData.profile);
  }
}

function copyAccountNumber() {
  if (!currentOverviewData || !currentOverviewData.accounts || !currentOverviewData.accounts[0]) return;
  const accNo = String(currentOverviewData.accounts[0].account_no);
  navigator.clipboard.writeText(accNo).then(() => {
    showToast(`Account number ${accNo} copied to clipboard`, 'success');
  });
}

/**
 * Render Smooth Spline Area Chart (Chart.js)
 */
function renderSplineChart(trendData) {
  const canvas = document.getElementById('balanceSplineChart');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  if (splineChart) {
    splineChart.destroy();
  }

  // Fallback data if trend is empty
  const labels = (trendData && trendData.length > 0)
    ? trendData.map(d => d.month_label)
    : ['May-2026', 'Jun-2026', 'Jul-2026', 'Aug-2026', 'Sep-2026', 'Oct-2026'];

  const credits = (trendData && trendData.length > 0)
    ? trendData.map(d => d.credits || 0)
    : [25000, 42000, 31000, 58000, 46000, 62000];

  const debits = (trendData && trendData.length > 0)
    ? trendData.map(d => d.debits || 0)
    : [18000, 22000, 19000, 31000, 28000, 34000];

  // Mint-Emerald Area Gradient for Credits
  const mintGradient = ctx.createLinearGradient(0, 0, 0, 200);
  mintGradient.addColorStop(0, 'rgba(52, 211, 153, 0.32)');
  mintGradient.addColorStop(1, 'rgba(52, 211, 153, 0.0)');

  // Warm Coral Area Gradient for Debits
  const coralGradient = ctx.createLinearGradient(0, 0, 0, 200);
  coralGradient.addColorStop(0, 'rgba(248, 113, 113, 0.18)');
  coralGradient.addColorStop(1, 'rgba(248, 113, 113, 0.0)');

  splineChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labels,
      datasets: [
        {
          label: 'Credits / Inflow',
          data: credits,
          borderColor: '#34D399',
          backgroundColor: mintGradient,
          borderWidth: 2.2,
          fill: true,
          tension: 0.42,
          pointRadius: 3,
          pointHoverRadius: 6,
          pointBackgroundColor: '#34D399',
          pointBorderColor: '#0A0F0D',
          pointBorderWidth: 2,
        },
        {
          label: 'Debits / Outflow',
          data: debits,
          borderColor: '#F87171',
          backgroundColor: coralGradient,
          borderWidth: 1.8,
          borderDash: [4, 4],
          fill: true,
          tension: 0.42,
          pointRadius: 2.5,
          pointHoverRadius: 5,
          pointBackgroundColor: '#F87171',
          pointBorderColor: '#0A0F0D',
          pointBorderWidth: 2,
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false,
      },
      plugins: {
        legend: { display: false },
        tooltip: {
          backgroundColor: '#0D1411',
          titleColor: '#E5E7EB',
          bodyColor: '#34D399',
          borderColor: '#1E2D27',
          borderWidth: 1,
          padding: 10,
          boxPadding: 4,
          usePointStyle: true,
          callbacks: {
            label: function(context) {
              const label = context.dataset.label || '';
              return ` ${label}: ${formatINR(context.raw)}`;
            }
          }
        }
      },
      scales: {
        x: {
          grid: { color: 'rgba(30, 45, 39, 0.4)', drawBorder: false },
          ticks: { color: '#6B7280', font: { family: 'JetBrains Mono', size: 10 } }
        },
        y: {
          grid: { color: 'rgba(30, 45, 39, 0.4)', drawBorder: false },
          ticks: {
            color: '#6B7280',
            font: { family: 'JetBrains Mono', size: 10 },
            callback: val => '₹' + (val >= 1000 ? (val / 1000) + 'k' : val)
          }
        }
      }
    }
  });
}

/**
 * Render Recent Transactions list
 */
function renderRecentTransactions(txns) {
  const container = document.getElementById('recent-transactions-list');
  const countBadge = document.getElementById('txns-count-badge');
  if (!container) return;

  if (!txns || txns.length === 0) {
    container.innerHTML = '<p class="text-xs text-gray-500 py-6 text-center italic">No transactions recorded for this customer.</p>';
    if (countBadge) countBadge.textContent = '0 entries';
    return;
  }

  if (countBadge) countBadge.textContent = `${txns.length} entries`;

  container.innerHTML = '';
  txns.forEach(t => {
    const isCredit = ['deposit', 'transfer_credit'].includes((t.transaction_type || '').toLowerCase());
    const sign = isCredit ? '+' : '-';
    const amountClass = isCredit ? 'text-emerald-400 font-bold' : 'text-gray-200 font-semibold';
    const iconBadge = isCredit
      ? '<div class="w-8 h-8 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0"><i data-lucide="arrow-down-left" class="w-4 h-4"></i></div>'
      : '<div class="w-8 h-8 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 flex items-center justify-center shrink-0"><i data-lucide="arrow-up-right" class="w-4 h-4"></i></div>';

    const row = document.createElement('div');
    row.className = 'p-3 rounded-xl bg-inset/40 hover:bg-inset border border-border-card/60 hover:border-emerald-500/30 flex items-center justify-between gap-3 transition';
    row.innerHTML = `
      <div class="flex items-center gap-3 overflow-hidden">
        ${iconBadge}
        <div class="overflow-hidden">
          <p class="text-xs font-semibold text-white truncate">${t.transaction_type || 'Transaction'}</p>
          <p class="text-[10px] font-mono text-gray-500 truncate mt-0.5">${t.transaction_mode || 'UPI'} • ${t.txn_date || ''} ${t.txn_time || ''}</p>
        </div>
      </div>
      <div class="text-right shrink-0">
        <p class="text-xs font-mono ${amountClass}">${sign}${formatINR(t.amount)}</p>
        <span class="text-[9px] font-mono text-gray-500">TXN #${t.transaction_id || ''}</span>
      </div>
    `;
    container.appendChild(row);
  });

  lucide.createIcons({ root: container });
}

/**
 * Render Cash Flow tinted boxes
 */
function renderCashFlow(cashflow) {
  const incEl = document.getElementById('cashflow-income-val');
  const expEl = document.getElementById('cashflow-expense-val');
  const labelEl = document.getElementById('cashflow-month-label');

  if (incEl) incEl.textContent = formatINR(cashflow ? cashflow.total_credits : 0);
  if (expEl) expEl.textContent = formatINR(cashflow ? cashflow.total_debits : 0);
  if (labelEl && cashflow && cashflow.month_label) {
    labelEl.textContent = cashflow.month_label;
  }
}

/**
 * Render Loan EMI and Fixed Deposit Tracker
 */
function renderLoansAndFds(loans, fds) {
  // Loan section
  if (loans && loans.length > 0) {
    const loan = loans[0];
    const principal = loan.principal_amount || 1;
    const paid = loan.total_paid || 0;
    const pct = Math.min(100, Math.round((paid / principal) * 100));

    const typeLabel = document.getElementById('loan-type-label');
    if (typeLabel) typeLabel.textContent = `${loan.loan_type || 'Personal'} Loan #${loan.loan_id}`;

    const repaidPct = document.getElementById('loan-repaid-pct');
    if (repaidPct) repaidPct.textContent = `${pct}% repaid`;

    const progBar = document.getElementById('loan-progress-bar');
    if (progBar) progBar.style.width = `${pct}%`;

    const paidVal = document.getElementById('loan-paid-val');
    if (paidVal) paidVal.textContent = `Paid: ${formatINR(paid)}`;

    const princVal = document.getElementById('loan-principal-val');
    if (princVal) princVal.textContent = `Principal: ${formatINR(principal)}`;

    const statusTag = document.getElementById('loan-status-tag');
    if (statusTag) statusTag.textContent = loan.status || 'Active';
  } else {
    const typeLabel = document.getElementById('loan-type-label');
    if (typeLabel) typeLabel.textContent = 'No Active Loans';
    const repaidPct = document.getElementById('loan-repaid-pct');
    if (repaidPct) repaidPct.textContent = '0% repaid';
    const progBar = document.getElementById('loan-progress-bar');
    if (progBar) progBar.style.width = '0%';
  }

  // Fixed Deposit section
  if (fds && fds.length > 0) {
    const fd = fds[0];
    const matVal = document.getElementById('fd-maturity-val');
    if (matVal) matVal.textContent = formatINR(fd.maturity_value);

    const sumVal = document.getElementById('fd-summary-val');
    if (sumVal) sumVal.textContent = `${formatINR(fd.principal_amount)} @ ${fd.interest_rate}%`;
  } else {
    const matVal = document.getElementById('fd-maturity-val');
    if (matVal) matVal.textContent = '₹0.00';
    const sumVal = document.getElementById('fd-summary-val');
    if (sumVal) sumVal.textContent = 'No Active FDs';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer Switcher
// ─────────────────────────────────────────────────────────────────────────────

async function loadCustomers() {
  try {
    const res = await fetch('/api/customers');
    const data = await res.json();
    const select = document.getElementById('customer-select');
    if (!select) return;

    select.innerHTML = '';
    const customers = data.rows || [];
    customers.forEach(c => {
      const opt = document.createElement('option');
      opt.value = c.customer_id;
      opt.className = 'bg-[#111916] text-white';
      opt.textContent = `${c.customer_id} - ${c.full_name}`;
      select.appendChild(opt);
    });

    if (customers.length > 0) {
      currentCustomerId = customers[0].customer_id;
      select.value = currentCustomerId;
      loadCustomerOverview(currentCustomerId);
    }
  } catch (err) {
    console.error('Failed to load customers:', err);
  }
}

function onCustomerChange(newCid) {
  currentCustomerId = parseInt(newCid, 10);
  loadCustomerOverview(currentCustomerId);
  showToast(`Switched to Customer #${currentCustomerId}`, 'info');
}

// ─────────────────────────────────────────────────────────────────────────────
// Views 2-5: The 4 Teammate Viva Modules
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Execute DML for Module 1
 */
async function executeModule1DML(action) {
  let payload = {};
  if (action === 'insert') {
    payload = {
      customer_id: parseInt(document.getElementById('m1-ins-cid').value, 10),
      account_no: parseInt(document.getElementById('m1-ins-acc').value, 10),
      account_type: document.getElementById('m1-ins-type').value,
      balance: parseFloat(document.getElementById('m1-ins-bal').value),
      branch_id: parseInt(document.getElementById('m1-ins-branch').value, 10)
    };
  } else if (action === 'update') {
    payload = {
      account_no: parseInt(document.getElementById('m1-upd-acc').value, 10),
      status: document.getElementById('m1-upd-status').value
    };
  } else if (action === 'delete') {
    payload = {
      customer_id: parseInt(document.getElementById('m1-del-cid').value, 10),
      phone_number: document.getElementById('m1-del-phone').value
    };
  }

  await callModuleDML(1, action, payload);
}

/**
 * Execute DML for Module 2
 */
async function executeModule2DML(action) {
  let payload = {};
  if (action === 'insert') {
    payload = {
      customer_id: parseInt(document.getElementById('m2-ins-cid').value, 10),
      beneficiary_name: document.getElementById('m2-ins-name').value,
      account_no: parseInt(document.getElementById('m2-ins-acc').value, 10),
      ifsc_code: document.getElementById('m2-ins-ifsc').value
    };
  } else if (action === 'update') {
    payload = {
      card_id: parseInt(document.getElementById('m2-upd-card').value, 10),
      status: document.getElementById('m2-upd-status').value
    };
  } else if (action === 'delete') {
    payload = {
      beneficiary_id: parseInt(document.getElementById('m2-del-bid').value, 10)
    };
  }

  await callModuleDML(2, action, payload);
}

/**
 * Execute DML for Module 3
 */
async function executeModule3DML(action) {
  let payload = {};
  if (action === 'insert') {
    payload = {
      customer_id: parseInt(document.getElementById('m3-ins-cid').value, 10),
      principal_amount: parseFloat(document.getElementById('m3-ins-principal').value),
      interest_rate: parseFloat(document.getElementById('m3-ins-rate').value),
      start_date: document.getElementById('m3-ins-start').value,
      maturity_date: document.getElementById('m3-ins-mat').value
    };
  } else if (action === 'update') {
    payload = {
      loan_id: parseInt(document.getElementById('m3-upd-lid').value, 10),
      field: document.getElementById('m3-upd-field').value,
      value: document.getElementById('m3-upd-val').value
    };
  } else if (action === 'delete') {
    payload = {
      fd_id: parseInt(document.getElementById('m3-del-fdid').value, 10)
    };
  }

  await callModuleDML(3, action, payload);
}

/**
 * Execute DML for Module 4
 */
async function executeModule4DML(action) {
  let payload = {};
  if (action === 'insert') {
    payload = {
      customer_id: parseInt(document.getElementById('m4-ins-cid').value, 10),
      description: document.getElementById('m4-ins-desc').value
    };
  } else if (action === 'update') {
    payload = {
      complaint_id: parseInt(document.getElementById('m4-upd-cmpid').value, 10),
      status: document.getElementById('m4-upd-status').value
    };
  } else if (action === 'delete') {
    payload = {
      complaint_id: parseInt(document.getElementById('m4-del-cmpid').value, 10)
    };
  }

  await callModuleDML(4, action, payload);
}

/**
 * Common DML invoker
 */
async function callModuleDML(modId, action, payload) {
  try {
    const res = await fetch(`/api/module/${modId}/${action}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const data = await res.json();
    if (!res.ok) {
      const trace = data.trace || (data.traces ? data.traces[0] : null);
      if (trace) updateExecutionTrace(trace, false, data.error);
      throw new Error(data.error || 'DML Failed');
    }

    const trace = data.trace || (data.traces ? data.traces[0] : null);
    if (trace) updateExecutionTrace(trace, true);

    if (modId === 1 && action === 'insert' && data.account_no) {
      showToast(`Account #${data.account_no} successfully opened in Oracle!`, 'success');
      const accInput = document.getElementById('m1-ins-acc');
      if (accInput) accInput.value = data.account_no + 1;
    } else {
      showToast(`Oracle DML ${action.toUpperCase()} successful (${data.rows_affected || 1} rows affected)`, 'success');
    }

    // Reload overview if customer matches
    loadCustomerOverview(currentCustomerId);
  } catch (err) {
    showToast(`Oracle DML Error: ${err.message}`, 'error');
  }
}

/**
 * Run one of the 20 labeled SELECT queries [Mx-Qy]
 */
async function runModuleQuery(modId, qNum) {
  const resultContainer = document.getElementById(`m${modId}-query-result`);
  if (!resultContainer) return;

  // Highlight active button
  const btns = document.querySelectorAll(`.q-btn-${modId}`);
  btns.forEach(b => {
    b.classList.remove('bg-sidebar-active', 'text-emerald-accent', 'border-emerald-accent');
  });
  const activeBtn = Array.from(btns).find(b => b.textContent.includes(`M${modId}-Q${qNum}`));
  if (activeBtn) {
    activeBtn.classList.add('bg-sidebar-active', 'text-emerald-accent', 'border-emerald-accent');
  }

  resultContainer.innerHTML = `
    <div class="p-6 text-center text-xs text-gray-400 font-mono flex items-center justify-center gap-2">
      <span class="w-3 h-3 border-2 border-emerald-400 border-t-transparent rounded-full animate-spin"></span>
      Executing [M${modId}-Q${qNum}] live in Oracle Database...
    </div>
  `;

  try {
    const res = await fetch(`/api/module-queries/${modId}/${qNum}`);
    if (!res.ok) throw new Error(`Query failed with status ${res.status}`);
    const data = await res.json();

    // Update bottom inspector
    if (data.trace) updateExecutionTrace(data.trace, true);

    // Render Query Result Card
    renderQueryResultTable(resultContainer, data, modId, qNum);
  } catch (err) {
    resultContainer.innerHTML = `
      <div class="p-4 rounded-xl bg-red-950/20 border border-red-500/40 text-red-300 text-xs font-mono">
        Error executing query: ${err.message}
      </div>
    `;
    showToast(`Query error: ${err.message}`, 'error');
  }
}

/**
 * Render sleek table with query metadata and raw SQL
 */
function renderQueryResultTable(container, data, modId, qNum) {
  const rows = data.rows || [];
  const count = data.count || rows.length;
  const description = data.description || `Query [M${modId}-Q${qNum}]`;
  const sql = data.trace ? data.trace.sql_executed : '';

  let tableHtml = '';
  if (rows.length === 0) {
    tableHtml = '<p class="p-4 text-xs font-mono text-gray-500 italic text-center">Query executed successfully, returned 0 rows.</p>';
  } else {
    const columns = Object.keys(rows[0]);
    tableHtml = `
      <div class="overflow-x-auto max-h-72 overflow-y-auto">
        <table class="w-full text-left border-collapse text-xs font-mono">
          <thead class="sticky top-0 bg-[#0B120F] border-b border-border-card text-[11px] text-gray-400 uppercase">
            <tr>
              ${columns.map(c => `<th class="p-2.5 font-semibold tracking-wider text-emerald-400/90 whitespace-nowrap">${c.replace(/_/g, ' ')}</th>`).join('')}
            </tr>
          </thead>
          <tbody class="divide-y divide-border-card/40">
            ${rows.map(row => `
              <tr class="hover:bg-inset/60 transition">
                ${columns.map(c => {
                  let val = row[c];
                  if (typeof val === 'number' && (c.includes('balance') || c.includes('amount') || c.includes('salary'))) {
                    val = formatINR(val);
                  }
                  return `<td class="p-2.5 text-gray-300 whitespace-nowrap">${val !== null && val !== undefined ? val : '<span class="text-gray-600">NULL</span>'}</td>`;
                }).join('')}
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;
  }

  container.innerHTML = `
    <div class="flex flex-col gap-3">
      <!-- Query Metadata Bar -->
      <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-3 rounded-xl bg-inset border border-border-card">
        <div>
          <div class="flex items-center gap-2">
            <span class="px-2 py-0.5 rounded text-[10px] font-mono font-bold bg-sidebar-active text-emerald-accent border border-emerald-500/20">M${modId}-Q${qNum}</span>
            <h4 class="text-xs font-bold text-white">${description}</h4>
          </div>
          <p class="text-[11px] font-mono text-gray-500 mt-1">Returned ${count} row(s) in ${data.trace ? data.trace.execution_ms : 0} ms</p>
        </div>
        <button onclick="copySqlText('${btoa(sql)}')" class="self-start sm:self-auto px-3 py-1 rounded-lg bg-card hover:bg-[#1a2520] border border-border-card text-[11px] font-mono text-gray-300 hover:text-emerald-accent transition flex items-center gap-1.5">
          <i data-lucide="copy" class="w-3 h-3"></i>
          <span>Copy SQL</span>
        </button>
      </div>

      <!-- Raw SQL Block -->
      <div class="nola-inset p-3 bg-[#080D0B] border border-border-card rounded-xl">
        <pre class="font-mono text-[11px] text-emerald-400/90 whitespace-pre-wrap break-all">${sql}</pre>
      </div>

      <!-- Result Table -->
      <div class="rounded-xl border border-border-card overflow-hidden bg-card">
        ${tableHtml}
      </div>
    </div>
  `;

  lucide.createIcons({ root: container });
}

function copySqlText(b64) {
  const sql = atob(b64);
  navigator.clipboard.writeText(sql).then(() => {
    showToast('SQL query copied to clipboard', 'info');
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// View 6: PL/SQL & Cursor Lab
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Execute sp_process_fund_transfer from Lab Card 1
 */
async function testLabTransfer() {
  const accNo = parseInt(document.getElementById('lab-p1-acc').value, 10);
  const beneId = parseInt(document.getElementById('lab-p1-bene').value, 10);
  const amount = parseFloat(document.getElementById('lab-p1-amt').value);
  const mode = document.getElementById('lab-p1-mode').value;

  try {
    const res = await fetch('/api/transfer', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        account_no: accNo,
        beneficiary_id: beneId,
        amount: amount,
        mode: mode
      })
    });

    const data = await res.json();
    if (res.ok) {
      updateExecutionTrace(data.trace, true);
      showToast(data.message || 'Transfer completed successfully', 'success');
      loadCustomerOverview(currentCustomerId);
    } else {
      updateExecutionTrace(data.trace, false, data.message);
      showToast(data.message || 'Transfer rejected by Oracle', 'error');
    }
  } catch (err) {
    showToast(`Execution error: ${err.message}`, 'error');
  }
}

/**
 * Trigger Breach Demo: Triggers trg_prevent_min_balance_breach (ORA-20001)
 */
async function testMinBalanceBreach() {
  const accNo = 10042011; // Savings account with balance
  const beneId = 601;

  // Amount guaranteed to breach minimum balance of ₹1,000
  // Savings balance is ~₹25,000, so transferring ₹24,800 leaves ₹200 (< 1000)
  const breachAmount = 24800;

  showToast('Testing trg_prevent_min_balance_breach... Attempting overdraw!', 'warning');

  try {
    const res = await fetch('/api/transfer', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        account_no: accNo,
        beneficiary_id: beneId,
        amount: breachAmount,
        mode: 'UPI'
      })
    });

    const data = await res.json();
    if (!res.ok) {
      // Trigger blocked as expected!
      updateExecutionTrace(data.trace, false, data.message);
      showToast(`Trigger Successful: ${data.message}`, 'error');

      // Expand terminal to show the professor the ORA-20001 message!
      if (!isFlowDrawerOpen) toggleFlowDrawer();
    } else {
      showToast('Transfer completed unexpectedly', 'info');
    }
  } catch (err) {
    showToast(`Breach test error: ${err.message}`, 'error');
  }
}

/**
 * Execute sp_pay_loan_emi from Lab Card 2
 */
async function testLabPayEmi() {
  const loanId = parseInt(document.getElementById('lab-p2-lid').value, 10);
  const amount = parseFloat(document.getElementById('lab-p2-amt').value);
  const mode = document.getElementById('lab-p2-mode').value;

  try {
    const res = await fetch('/api/pay-emi', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        loan_id: loanId,
        amount: amount,
        mode: mode
      })
    });

    const data = await res.json();
    if (res.ok) {
      updateExecutionTrace(data.trace, true);
      showToast(data.message || 'EMI payment processed', 'success');
      loadCustomerOverview(currentCustomerId);
    } else {
      updateExecutionTrace(data.trace, false, data.message);
      showToast(data.message || 'EMI payment failed', 'error');
    }
  } catch (err) {
    showToast(`Execution error: ${err.message}`, 'error');
  }
}

/**
 * Test fn_get_customer_age
 */
async function testCustomerAgeFunc() {
  const cid = parseInt(document.getElementById('lab-fn-age-cid').value, 10);
  const resEl = document.getElementById('lab-fn-age-res');

  try {
    const res = await fetch(`/api/overview/${cid}`);
    const data = await res.json();
    const age = data.profile ? data.profile.age : 0;
    const dob = data.profile ? data.profile.date_of_birth : '--';

    if (resEl) {
      resEl.classList.remove('hidden');
      resEl.innerHTML = `
        <span class="text-white">Customer #${cid}</span><br>
        Date of Birth: <span class="text-gray-300">${dob}</span><br>
        Derived Age: <span class="text-emerald-400 font-bold">${age} years</span>
      `;
    }
    if (data.traces && data.traces.profile) {
      updateExecutionTrace(data.traces.profile, true);
    }
    showToast(`fn_get_customer_age(${cid}) returned ${age} years`, 'success');
  } catch (err) {
    showToast(`Error evaluating function: ${err.message}`, 'error');
  }
}

/**
 * Test fn_calc_fd_maturity_value
 */
async function testFdMaturityFunc() {
  const fdid = parseInt(document.getElementById('lab-fn-fd-id').value, 10);
  const resEl = document.getElementById('lab-fn-fd-res');

  try {
    // Run module 3 query 2 which selects fn_calc_fd_maturity_value
    const res = await fetch(`/api/module-queries/3/2`);
    const data = await res.json();
    const match = (data.rows || []).find(r => r.fd_id === fdid) || (data.rows && data.rows[0]);

    if (resEl && match) {
      resEl.classList.remove('hidden');
      resEl.innerHTML = `
        <span class="text-white">FD #${match.fd_id}</span> • Customer #${match.customer_id}<br>
        Principal: <span class="text-gray-300">${formatINR(match.principal_amount)}</span> @ <span class="text-gray-300">${match.interest_rate}%</span><br>
        Tenure: <span class="text-gray-300">${match.tenure_years} yrs</span><br>
        Compound Maturity: <span class="text-emerald-400 font-bold text-sm">${formatINR(match.maturity_value)}</span>
      `;
    }
    if (data.trace) updateExecutionTrace(data.trace, true);
    showToast(`fn_calc_fd_maturity_value evaluated`, 'success');
  } catch (err) {
    showToast(`Error: ${err.message}`, 'error');
  }
}

/**
 * Trigger 2 Demo: Changing Complaint to 'Resolved' auto-stamps Resolution_Date
 */
async function testComplaintResolutionTrigger() {
  try {
    const res = await fetch('/api/module/4/update', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        complaint_id: 901,
        status: 'Resolved'
      })
    });
    const data = await res.json();
    if (res.ok) {
      updateExecutionTrace(data.trace, true);
      showToast('Trigger 2 fired! Status changed to Resolved; Resolution_Date stamped := SYSDATE', 'success');
      if (!isFlowDrawerOpen) toggleFlowDrawer();
    }
  } catch (err) {
    showToast(`Error: ${err.message}`, 'error');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal 1: Fund Transfer Modal
// ─────────────────────────────────────────────────────────────────────────────

function openTransferModal() {
  const modal = document.getElementById('transferModal');
  if (modal) modal.classList.remove('hidden');
  lucide.createIcons();
}

function closeTransferModal() {
  const modal = document.getElementById('transferModal');
  if (modal) modal.classList.add('hidden');
}

function selectTransferMode(mode) {
  selectedTransferMode = mode;
  const btns = document.querySelectorAll('.mode-btn');
  btns.forEach(b => {
    if (b.getAttribute('data-mode') === mode) {
      b.className = 'mode-btn px-2 py-2 rounded-xl text-xs font-mono font-medium border border-emerald-500 bg-sidebar-active text-emerald-accent text-center';
    } else {
      b.className = 'mode-btn px-2 py-2 rounded-xl text-xs font-mono font-medium border border-border-card bg-inset text-gray-300 hover:border-emerald-accent text-center';
    }
  });
}

function populateTransferModalOptions(accounts, beneficiaries) {
  const accSelect = document.getElementById('transfer-src-account');
  const beneSelect = document.getElementById('transfer-beneficiary');

  if (accSelect) {
    accSelect.innerHTML = '';
    (accounts || []).forEach(a => {
      const opt = document.createElement('option');
      opt.value = a.account_no;
      opt.className = 'bg-[#111916] text-white';
      opt.textContent = `${a.account_no} (${a.account_type}) — Balance: ${formatINR(a.balance_raw)}`;
      accSelect.appendChild(opt);
    });
  }

  if (beneSelect) {
    beneSelect.innerHTML = '';
    (beneficiaries || []).forEach(b => {
      const opt = document.createElement('option');
      opt.value = b.beneficiary_id;
      opt.className = 'bg-[#111916] text-white';
      opt.textContent = `${b.beneficiary_name} (${b.account_no} • ${b.ifsc_code})`;
      beneSelect.appendChild(opt);
    });
  }
}

/**
 * Preset button: Fills transfer amount to trigger minimum balance breach
 */
function presetTriggerBreach() {
  if (!currentOverviewData || !currentOverviewData.accounts || currentOverviewData.accounts.length === 0) return;
  const primary = currentOverviewData.accounts[0];
  const balance = primary.balance_raw || 25000;

  // Set amount so remaining balance is less than 1,000 (e.g. ₹500 left)
  const overdrawAmount = Math.max(100, balance - 500);

  const amtInput = document.getElementById('transfer-amount');
  if (amtInput) amtInput.value = overdrawAmount;

  showToast(`Preset applied: Transfer of ${formatINR(overdrawAmount)} will breach ₹1,000 min balance!`, 'warning');
}

async function submitTransfer() {
  const accNo = parseInt(document.getElementById('transfer-src-account').value, 10);
  const beneId = parseInt(document.getElementById('transfer-beneficiary').value, 10);
  const amount = parseFloat(document.getElementById('transfer-amount').value);
  const btn = document.getElementById('btn-submit-transfer');

  if (!accNo || !beneId || isNaN(amount) || amount <= 0) {
    showToast('Please specify valid account, beneficiary, and amount', 'error');
    return;
  }

  if (btn) btn.disabled = true;

  try {
    const res = await fetch('/api/transfer', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        account_no: accNo,
        beneficiary_id: beneId,
        amount: amount,
        mode: selectedTransferMode
      })
    });

    const data = await res.json();
    closeTransferModal();

    if (res.ok) {
      updateExecutionTrace(data.trace, true);
      showToast(data.message || 'Transfer completed successfully', 'success');
      loadCustomerOverview(currentCustomerId);
    } else {
      updateExecutionTrace(data.trace, false, data.message);
      showToast(`Trigger Blocked: ${data.message}`, 'error');
      // Auto expand execution inspector
      if (!isFlowDrawerOpen) toggleFlowDrawer();
    }
  } catch (err) {
    showToast(`Transfer error: ${err.message}`, 'error');
  } finally {
    if (btn) btn.disabled = false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal 2: Pay EMI Modal
// ─────────────────────────────────────────────────────────────────────────────

function openEmiModal() {
  const modal = document.getElementById('emiModal');
  if (modal) modal.classList.remove('hidden');
  lucide.createIcons();
}

function closeEmiModal() {
  const modal = document.getElementById('emiModal');
  if (modal) modal.classList.add('hidden');
}

function populateEmiModalOptions(loans) {
  const select = document.getElementById('emi-loan-select');
  if (!select) return;

  select.innerHTML = '';
  (loans || []).forEach(l => {
    const opt = document.createElement('option');
    opt.value = l.loan_id;
    opt.className = 'bg-[#111916] text-white';
    opt.textContent = `Loan #${l.loan_id} (${l.loan_type}) — Outstanding: ${formatINR(l.outstanding)}`;
    select.appendChild(opt);
  });
}

async function submitEmiPayment() {
  const loanId = parseInt(document.getElementById('emi-loan-select').value, 10);
  const amount = parseFloat(document.getElementById('emi-amount').value);
  const mode = document.getElementById('emi-mode').value;

  if (!loanId || isNaN(amount) || amount <= 0) {
    showToast('Please enter a valid loan and amount', 'error');
    return;
  }

  try {
    const res = await fetch('/api/pay-emi', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        loan_id: loanId,
        amount: amount,
        mode: mode
      })
    });

    const data = await res.json();
    closeEmiModal();

    if (res.ok) {
      updateExecutionTrace(data.trace, true);
      showToast(data.message || 'EMI paid successfully', 'success');
      loadCustomerOverview(currentCustomerId);
    } else {
      updateExecutionTrace(data.trace, false, data.message);
      showToast(data.message || 'EMI payment failed', 'error');
    }
  } catch (err) {
    showToast(`EMI error: ${err.message}`, 'error');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal 3: Branch Cursor Audit Report Modal
// ─────────────────────────────────────────────────────────────────────────────

async function openCursorModal() {
  const modal = document.getElementById('cursorModal');
  const content = document.getElementById('cursor-report-content');
  if (modal) modal.classList.remove('hidden');

  if (content) {
    content.innerHTML = `
      <div class="p-8 text-center text-xs text-gray-400 font-mono flex items-center justify-center gap-2">
        <span class="w-3.5 h-3.5 border-2 border-emerald-400 border-t-transparent rounded-full animate-spin"></span>
        Executing sp_branch_audit_cursor with explicit cursor cur_branch_performance...
      </div>
    `;
  }

  try {
    const res = await fetch('/api/cursor-report');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();

    if (data.trace) updateExecutionTrace(data.trace, true);

    const rows = data.rows || [];
    let totAccounts = 0;
    let totBalance = 0;
    let totEmployees = 0;

    rows.forEach(r => {
      totAccounts += r.total_accounts || 0;
      totBalance += r.total_balance || 0;
      totEmployees += r.total_employees || 0;
    });

    if (content) {
      content.innerHTML = `
        <table class="w-full text-left border-collapse text-xs font-mono">
          <thead class="sticky top-0 bg-[#0B120F] border-b border-border-card text-[11px] text-gray-400 uppercase">
            <tr>
              <th class="p-2.5 font-semibold text-emerald-400">Branch ID</th>
              <th class="p-2.5 font-semibold text-emerald-400">Branch Name</th>
              <th class="p-2.5 font-semibold text-emerald-400">IFSC Code</th>
              <th class="p-2.5 font-semibold text-right text-emerald-400">Accounts</th>
              <th class="p-2.5 font-semibold text-right text-emerald-400">Total Deposits</th>
              <th class="p-2.5 font-semibold text-right text-emerald-400">Employees</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-border-card/40">
            ${rows.map(r => `
              <tr class="hover:bg-inset/60 transition">
                <td class="p-2.5 font-semibold text-white">#${r.branch_id}</td>
                <td class="p-2.5 text-gray-200">${r.branch_name}</td>
                <td class="p-2.5 text-gray-400">${r.ifsc_code}</td>
                <td class="p-2.5 text-right font-semibold text-emerald-300">${r.total_accounts}</td>
                <td class="p-2.5 text-right font-bold text-white">${formatINR(r.total_balance)}</td>
                <td class="p-2.5 text-right text-gray-300">${r.total_employees}</td>
              </tr>
            `).join('')}
          </tbody>
          <tfoot class="sticky bottom-0 bg-[#0E1613] border-t-2 border-emerald-500/40 font-bold text-emerald-400">
            <tr>
              <td colspan="3" class="p-2.5 uppercase tracking-wider">System Total (10 Branches)</td>
              <td class="p-2.5 text-right">${totAccounts}</td>
              <td class="p-2.5 text-right text-white">${formatINR(totBalance)}</td>
              <td class="p-2.5 text-right">${totEmployees}</td>
            </tr>
          </tfoot>
        </table>
      `;
    }
  } catch (err) {
    if (content) {
      content.innerHTML = `<div class="p-4 text-xs font-mono text-red-400">Failed to generate branch cursor report: ${err.message}</div>`;
    }
  }
}

function closeCursorModal() {
  const modal = document.getElementById('cursorModal');
  if (modal) modal.classList.add('hidden');
}

// ─────────────────────────────────────────────────────────────────────────────
// Initialisation on Page Load
// ─────────────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  // Format current date in header
  const topDateEl = document.getElementById('top-date');
  if (topDateEl) {
    const now = new Date();
    const opts = { weekday: 'long', year: 'numeric', month: 'short', day: 'numeric' };
    topDateEl.textContent = now.toLocaleDateString('en-IN', opts);
  }

  // Load customer switcher and initial Bento Grid
  loadCustomers();

  // Initialize Lucide icons
  lucide.createIcons();
});
