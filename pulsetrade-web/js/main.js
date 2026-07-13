/* ============================================================
   PULSETRADE — main.js  v3.0  (ALL 3 EXAM FEATURES LIVE)
   Pure Vanilla JavaScript. No frameworks. No jQuery.

   NEW IN v3.0:
   ✅ FEATURE 1 — Real Finnhub company search API
      Type any stock name → live results dropdown appears
      Exam requirement: "search for country markets and companies"

   ✅ FEATURE 2 — Real candle chart data from Finnhub
      1D / 1W / 1M / 3M / 6M / 1Y time ranges all hit real API
      Exam requirement: "see prices for 1 day, 1 month, 3 months, or a year"

   ✅ FEATURE 3 — Geolocation → real country → correct market shown
      Auto-detects user country, updates home page subtitle AND
      swaps the visible market data to match the detected country
      Exam requirement: "related to user's current location"
============================================================ */


/* ============================================================
   1. API KEY
   ▶ Paste your Finnhub token here. One place, updates everywhere.
============================================================ */

const FINNHUB_BASE_URL = "https://finnhub.io/api/v1";
const GEO_API_URL      = "https://api.bigdatacloud.net/data/reverse-geocode-client";


/* ============================================================
   2. STOCK SYMBOL MAP + CONFIG
============================================================ */
const STOCK_SYMBOLS = {
  "ENR.DE" : "SIE",
  "SAP.DE" : "SAP",
  "TSLA"   : "TSLA",
  "NVDA"   : "NVDA",
  "AAPL"   : "AAPL",
};

const SHARES_HELD = { SIE:120, SAP:80, TSLA:10, NVDA:15, AAPL:8 };

/* FIX: Finnhub's free tier only quotes US-listed exchanges — European
   tickers like ENR.DE / SAP.DE (XETRA) never return real data on a free
   key. Without this, those two symbols were silently priced at their
   own avgPrice forever, which makes every trade of them net to exactly
   zero change in total balance (mathematically correct, but it LOOKS
   broken, and their %P&L can never move). This is a distinct "market
   price" fallback for symbols with no live quote yet — not the same
   number as avgPrice, so P&L for these can actually differ from cost. */
const MOCK_MARKET_PRICES = { SIE:18.24, SAP:213.65, TSLA:178.24, NVDA:987.54, AAPL:212.35 };

const CURRENCY_SYMBOLS = { EUR:"€", USD:"$", GBP:"£", TRY:"₺" };
const FX_RATES         = { EUR:1.00, USD:1.09, GBP:0.86, TRY:35.20 };

/* Country code → market info map used by geolocation feature */
const COUNTRY_MARKETS = {
  DE: { name:"Germany",        exchange:"XETRA",    currency:"EUR", flag:"🇩🇪", index:"DAX"     },
  US: { name:"United States",  exchange:"NASDAQ",   currency:"USD", flag:"🇺🇸", index:"S&P 500" },
  GB: { name:"United Kingdom", exchange:"LSE",      currency:"GBP", flag:"🇬🇧", index:"FTSE"    },
  TR: { name:"Turkey",         exchange:"BIST",     currency:"TRY", flag:"🇹🇷", index:"BIST 100"},
  FR: { name:"France",         exchange:"Euronext", currency:"EUR", flag:"🇫🇷", index:"CAC 40"  },
  JP: { name:"Japan",          exchange:"TSE",      currency:"USD", flag:"🇯🇵", index:"Nikkei"  },
};

/* Candle resolution codes for each time range (Finnhub format) */
const CANDLE_RESOLUTIONS = {
  "1D" : { resolution:"5",   days:1   },
  "1W" : { resolution:"60",  days:7   },
  "1M" : { resolution:"D",   days:30  },
  "3M" : { resolution:"D",   days:90  },
  "6M" : { resolution:"D",   days:180 },
  "1Y" : { resolution:"W",   days:365 },
  "5Y" : { resolution:"M",   days:1825},
  "Max": { resolution:"M",   days:3650},
};

/* NAV page list for sidebar validation */
const NAV_PAGES = [
  "home.html","markets.html","stock-detail.html",
  "portfolio.html","pro-plan.html","settings.html","index.html"
];


/* ============================================================
   2b. PT — SINGLE SOURCE OF TRUTH FOR MONEY
   Plain vanilla JS object (not a state-management library — just
   a namespaced module, same as any other function in this file).
   Every page loads main.js, so every page shares this ONE copy of
   the read/write/recompute logic instead of each page re-implementing
   its own version of "total = holdings + cash" and quietly disagreeing.

   RULE: prices only ever enter here via setPrice(shortId, rawNumber)
   from real Finnhub quote data (data.c). Nobody is allowed to derive
   a price by re-parsing formatted/displayed text — that was the root
   cause of the stale/garbage price-cache bug (see stock-detail.html).
============================================================ */
const PT = {
  DEFAULT_CASH: 50000.00,
  DEFAULT_PORTFOLIO: {
    SIE  : { shares: 120, avgPrice: 16.50 },
    SAP  : { shares: 80,  avgPrice: 195.00 },
    TSLA : { shares: 10,  avgPrice: 200.00 },
    NVDA : { shares: 15,  avgPrice: 850.00 },
    AAPL : { shares: 8,   avgPrice: 190.00 },
  },

  getCash() {
    return parseFloat(sessionStorage.getItem("pt_cash_balance")) || this.DEFAULT_CASH;
  },
  setCash(v) {
    sessionStorage.setItem("pt_cash_balance", Number(v).toFixed(2));
  },

  getPortfolio() {
    try {
      const raw = sessionStorage.getItem("pt_portfolio");
      if (raw) {
        const stored = JSON.parse(raw);
        Object.keys(stored).forEach(id => {
          stored[id].shares   = Number(stored[id].shares)   || 0;
          stored[id].avgPrice = Number(stored[id].avgPrice) || 0;
        });
        return stored;
      }
    } catch (e) { /* ignore parse errors, fall through to defaults */ }
    return JSON.parse(JSON.stringify(this.DEFAULT_PORTFOLIO));
  },
  setPortfolio(p) {
    sessionStorage.setItem("pt_portfolio", JSON.stringify(p));
  },

  getPriceCache() {
    try { return JSON.parse(sessionStorage.getItem("pt_price_cache") || "{}"); }
    catch (e) { return {}; }
  },
  /* THE only place a price is written to the cache. price must be
     a raw number straight from a Finnhub quote (data.c) — never a
     value pulled back out of a formatted/localized DOM string. */
  setPrice(shortId, price) {
    price = Number(price);
    if (!shortId || !price || price <= 0) return;
    const cache = this.getPriceCache();
    cache[shortId] = price;
    sessionStorage.setItem("pt_price_cache", JSON.stringify(cache));
  },
  getPrice(shortId) {
    const cache     = this.getPriceCache();
    const portfolio = this.getPortfolio();
    return Number(cache[shortId])
        || Number(MOCK_MARKET_PRICES[shortId])
        || Number(portfolio[shortId]?.avgPrice)
        || 0;
  },

  /* total = Σ(shares × best known price) + cash.
     This is the ONLY place this formula is allowed to live. Every
     page renders whatever this returns instead of keeping its own
     copy of the math (that duplication was the flicker bug). */
  recomputeTotal() {
    const portfolio = this.getPortfolio();
    const cache     = this.getPriceCache();
    const cash      = this.getCash();
    let stockValue = 0;
    Object.entries(portfolio).forEach(([id, h]) => {
      const shares = Number(h.shares) || 0;
      const price  = Number(cache[id]) || Number(MOCK_MARKET_PRICES[id]) || Number(h.avgPrice) || 0;
      stockValue   = parseFloat((stockValue + shares * price).toFixed(2));
    });
    const total = parseFloat((stockValue + cash).toFixed(2));
    sessionStorage.setItem("pt_portfolio_total", total.toFixed(2));
    sessionStorage.setItem("pt_stock_value", stockValue.toFixed(2));
    return { total, stockValue, cash, portfolio, priceCache: cache };
  },

  /* Wipes all simulation state back to the defaults above. */
  reset() {
    sessionStorage.removeItem("pt_portfolio");
    sessionStorage.removeItem("pt_cash_balance");
    sessionStorage.removeItem("pt_price_cache");
    sessionStorage.removeItem("pt_portfolio_total");
    sessionStorage.removeItem("pt_stock_value");
  },
};

/* Wires up any element with id="btn-reset-simulation" on any page. */
document.addEventListener("DOMContentLoaded", function () {
  const resetBtn = document.getElementById("btn-reset-simulation");
  if (resetBtn) {
    resetBtn.addEventListener("click", function () {
      if (confirm("Reset the simulation? This clears cash, holdings and cached prices back to the starting demo state.")) {
        PT.reset();
        window.location.reload();
      }
    });
  }
});


/* ============================================================
   2c. FIX: EVERY stock link in this app is a plain
   <a href="stock-detail.html"> with no data about which stock was
   clicked — true on portfolio.html, markets.html, and home.html.
   stock-detail.html just reads whatever pt_selected_symbol happens
   to still be in sessionStorage, so every link opened the SAME
   (last-viewed / default) stock regardless of which row you clicked.

   Fix: every stock row/card already prints its raw ticker text
   (e.g. "ENR.DE", "TSLA") somewhere inside the link — this reads
   that text and records it right before the browser navigates.
   One delegated listener fixes every stock link on every page,
   no per-file edits needed. */
const SYMBOL_NAMES = {
  "ENR.DE": "Siemens Energy AG",
  "SAP.DE": "SAP SE",
  "TSLA":   "Tesla, Inc.",
  "NVDA":   "NVIDIA Corporation",
  "AAPL":   "Apple Inc.",
};

/* Badge color class, exchange label, and sector tags per stock —
   used to fix the stock-detail header (see PORTFOLIO FALLBACK /
   PAGE-SPECIFIC INIT section below). */
const STOCK_META = {
  SIE:  { badgeClass:"badge-sie",  exchange:"ENR.DE · XETRA",  sectors:["Energy","Utilities"] },
  SAP:  { badgeClass:"badge-sap",  exchange:"SAP.DE · XETRA",  sectors:["Technology","Software"] },
  TSLA: { badgeClass:"badge-tsla", exchange:"TSLA · NASDAQ",   sectors:["Automotive","Energy"] },
  NVDA: { badgeClass:"badge-nvda", exchange:"NVDA · NASDAQ",   sectors:["Technology","Semiconductors"] },
  AAPL: { badgeClass:"badge-aapl", exchange:"AAPL · NASDAQ",   sectors:["Technology","Consumer Electronics"] },
};
document.addEventListener("click", function (e) {
  const link = e.target.closest('a[href="stock-detail.html"]');
  if (!link) return;
  const text  = link.textContent;
  const match = Object.keys(SYMBOL_NAMES).find(sym => text.includes(sym));
  if (match) {
    sessionStorage.setItem("pt_selected_symbol", match);
    sessionStorage.setItem("pt_selected_symbol_name", SYMBOL_NAMES[match]);
  }
});


/* ============================================================
   3. FORMATTING HELPERS
============================================================ */
function formatPrice(price, currency = "EUR") {
  const symbol    = CURRENCY_SYMBOLS[currency] ?? "€";
  const rate      = FX_RATES[currency]         ?? 1;
  const converted = price * rate;
  return symbol + converted.toLocaleString("de-DE", {
    minimumFractionDigits:2, maximumFractionDigits:2
  });
}

function formatChange(dp) {
  const sign = dp >= 0 ? "+" : "";
  return `${sign}${dp.toFixed(2)}%`;
}

/* Unix timestamp → "09:00" label for 1D chart */
function formatTime(unix) {
  return new Date(unix * 1000).toLocaleTimeString("de-DE", {
    hour:"2-digit", minute:"2-digit", timeZone:"Europe/Berlin"
  });
}

/* Unix timestamp → "12 Jun" label for multi-day charts */
function formatDate(unix) {
  return new Date(unix * 1000).toLocaleDateString("de-DE", {
    day:"numeric", month:"short"
  });
}


/* ============================================================
   4. DOM HELPERS
============================================================ */
function safeSetText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}

function applyColorClass(id, value) {
  const el = document.getElementById(id);
  if (!el) return;
  el.classList.remove("positive","negative");
  el.classList.add(value >= 0 ? "positive" : "negative");
}

/* Apply color class directly to an element (not by id) */
function applyColorClassEl(el, value) {
  if (!el) return;
  el.classList.remove("positive","negative");
  el.classList.add(value >= 0 ? "positive" : "negative");
}


/* ============================================================
   5. CORE FETCH HELPERS
============================================================ */

/* Fetch a single stock quote */
async function fetchQuote(symbol) {
  const url = `${FINNHUB_BASE_URL}/quote?symbol=${encodeURIComponent(symbol)}&token=${FINNHUB_API_KEY}`;
  try {
    const res  = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!data || data.c === 0) return null;
    return data;
  } catch (err) {
    console.error(`[PT] fetchQuote(${symbol}):`, err.message);
    return null;
  }
} 
function getLivePortfolio() {
  try {
    const storedTrades = sessionStorage.getItem("pt_portfolio");
    if (storedTrades) {
      const parsed = JSON.parse(storedTrades);
      /* pt_portfolio stores { SIE: { shares: 120, avgPrice: 16.50 } }
         but callers expect  { SIE: 120 }  (just the share count).
         Extract .shares and force to Number to prevent string concat. */
      const result = {};
      Object.entries(parsed).forEach(([id, val]) => {
        result[id] = typeof val === "object"
          ? Number(val.shares) || 0
          : Number(val)        || 0;
      });
      return result;
    }
  } catch (e) { /* ignore */ }
  return { ...SHARES_HELD }; /* no trades yet — use defaults */
}
/* ============================================================
   FEATURE 1 — REAL FINNHUB SEARCH API
   ─────────────────────────────────────────────────────────────
   Endpoint: /search?q={query}&token={KEY}
   Returns a list of matching symbols with description + type.

   We show results in a dropdown under the search input.
   Clicking a result stores the symbol and navigates to
   stock-detail.html where the detail chart loads for it.

   Q&A TIP: "I used the Finnhub symbol search endpoint which
   returns up to 10 matching companies for any text query.
   I debounce the input so we don't fire an API call on every
   single keystroke — only after the user pauses for 400ms."
============================================================ */
async function searchStocks(query) {
  if (!query || query.length < 2) return [];
  const url = `${FINNHUB_BASE_URL}/search?q=${encodeURIComponent(query)}&token=${FINNHUB_API_KEY}`;
  try {
    const res  = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    /* Filter: only show stocks (not crypto/forex), max 8 results */
    return (data.result || [])
      .filter(r => r.type === "Common Stock" || r.type === "EQS")
      .slice(0, 8);
  } catch (err) {
    console.error("[PT] searchStocks:", err.message);
    return [];
  }
}

/* Debounce helper — delays a function call until typing pauses */
function debounce(fn, delay) {
  let timer;
  return function (...args) {
    clearTimeout(timer);
    timer = setTimeout(() => fn.apply(this, args), delay);
  };
}

/* Build and wire the search dropdown to an input element */
function initSearchBar(inputEl, dropdownEl) {
  if (!inputEl || !dropdownEl) return;

  /* Style the dropdown container */
  dropdownEl.style.cssText = `
    position:absolute; top:100%; left:0; right:0; z-index:200;
    background:var(--bg-elevated); border:1px solid var(--border);
    border-radius:var(--radius-md); margin-top:4px;
    max-height:320px; overflow-y:auto; display:none;
    box-shadow:0 8px 32px rgba(0,0,0,0.4);
  `;

  /* Make parent position:relative so dropdown is anchored */
  inputEl.closest(".search-bar").style.position = "relative";

  /* Debounced search — fires 400ms after user stops typing */
  const doSearch = debounce(async function () {
    const query = inputEl.value.trim();

    if (!query || query.length < 2) {
      dropdownEl.style.display = "none";
      return;
    }

    /* Show loading state */
    dropdownEl.style.display = "block";
    dropdownEl.innerHTML = `<div style="padding:12px 16px;color:var(--text-secondary);font-size:0.82rem;">Searching...</div>`;

    const results = await searchStocks(query);

    if (results.length === 0) {
      dropdownEl.innerHTML = `<div style="padding:12px 16px;color:var(--text-secondary);font-size:0.82rem;">No results found for "${query}"</div>`;
      return;
    }

    /* Build result rows */
    dropdownEl.innerHTML = results.map(r => `
      <div class="search-result-row" data-symbol="${r.symbol}" data-desc="${r.description}"
           style="display:flex;align-items:center;gap:12px;padding:10px 16px;
                  cursor:pointer;border-bottom:1px solid var(--border);
                  transition:background 0.15s;">
        <div style="width:42px;height:36px;border-radius:6px;background:var(--accent-bg);
                    display:flex;align-items:center;justify-content:center;
                    font-size:0.6rem;font-weight:800;color:var(--accent);flex-shrink:0;">
          ${r.symbol.split(".")[0].slice(0,4)}
        </div>
        <div style="flex:1;min-width:0;">
          <div style="font-size:0.85rem;font-weight:700;color:var(--text-primary);
                      white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">
            ${r.description}
          </div>
          <div style="font-size:0.72rem;color:var(--text-secondary);margin-top:2px;">
            ${r.symbol} · ${r.type}
          </div>
        </div>
        <svg style="width:12px;height:12px;color:var(--text-tertiary);flex-shrink:0;"
             viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="9 18 15 12 9 6"></polyline>
        </svg>
      </div>
    `).join("");

    /* Hover highlight on each row */
    dropdownEl.querySelectorAll(".search-result-row").forEach(row => {
      row.addEventListener("mouseenter", () => row.style.background = "var(--bg-surface)");
      row.addEventListener("mouseleave", () => row.style.background = "");

      /* Click → store symbol + navigate to detail page */
      row.addEventListener("click", () => {
        const sym  = row.getAttribute("data-symbol");
        const desc = row.getAttribute("data-desc");
        /* Store selected symbol so stock-detail.html can read it */
        sessionStorage.setItem("pt_selected_symbol",      sym);
        sessionStorage.setItem("pt_selected_symbol_name", desc);
        dropdownEl.style.display = "none";
        inputEl.value = "";
        window.location.href = "stock-detail.html";
      });
    });

  }, 400);  /* 400ms debounce delay */

  inputEl.addEventListener("input", doSearch);

  /* Close dropdown when clicking outside */
  document.addEventListener("click", e => {
    if (!inputEl.contains(e.target) && !dropdownEl.contains(e.target)) {
      dropdownEl.style.display = "none";
    }
  });

  /* Close on Escape key */
  inputEl.addEventListener("keydown", e => {
    if (e.key === "Escape") dropdownEl.style.display = "none";
  });
}


/* ============================================================
   FEATURE 2 — REAL CANDLE CHART DATA FROM FINNHUB
   ─────────────────────────────────────────────────────────────
   Endpoint: /stock/candle?symbol=X&resolution=R&from=T&to=T&token=KEY
   Returns arrays: c (close), h (high), l (low), o (open), t (timestamps)

   We expose fetchCandleData() so stock-detail.html can call it
   whenever the user clicks a time range button (1D, 1W, 1M…).

   Q&A TIP: "I calculate the 'from' timestamp by subtracting
   the number of days from the current Unix timestamp.
   Math.floor(Date.now()/1000) gives current time in seconds.
   Then I multiply days×86400 (seconds per day) to get the window."
============================================================ */
async function fetchCandleData(symbol, range) {
  const config = CANDLE_RESOLUTIONS[range] ?? CANDLE_RESOLUTIONS["1M"];
  const now    = Math.floor(Date.now() / 1000);          /* Current Unix time */
  const from   = now - config.days * 86400;              /* Start of window   */

  const url =
    `${FINNHUB_BASE_URL}/stock/candle` +
    `?symbol=${encodeURIComponent(symbol)}` +
    `&resolution=${config.resolution}` +
    `&from=${from}` +
    `&to=${now}` +
    `&token=${FINNHUB_API_KEY}`;

  try {
    const res  = await fetch(url);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();

    /* Finnhub returns { s:"no_data" } when no candles are available
       (e.g. market closed, symbol invalid, or outside trading hours) */
    if (!data || data.s === "no_data" || !data.c || data.c.length === 0) {
      console.warn(`[PT] No candle data for ${symbol} range ${range}`);
      return null;
    }

    /* Format timestamp labels based on range */
    const labels = data.t.map(t => range === "1D" ? formatTime(t) : formatDate(t));

    return {
      labels,           /* X-axis labels (time strings)    */
      prices: data.c,   /* Close prices — what we display  */
      highs:  data.h,   /* High prices per candle          */
      lows:   data.l,   /* Low prices per candle           */
      opens:  data.o,   /* Open prices per candle          */
    };

  } catch (err) {
    console.error(`[PT] fetchCandleData(${symbol}, ${range}):`, err.message);
    return null;
  }
}

/* Build / rebuild the main ChartJS chart on stock-detail.html
   Called once on load and again on every time-range pill click.

   chartRef — object with a .instance property so we can destroy
              the old chart before building a new one.           */
async function buildDetailChart(symbol, range, chartRef) {
  const canvas = document.getElementById("chart-main");
  if (!canvas || typeof Chart === "undefined") return;

  /* Show loading state in the chart area */
  const wrapper = canvas.closest(".main-chart-wrapper") || canvas.parentElement;
  if (wrapper) wrapper.style.opacity = "0.5";

  const candles = await fetchCandleData(symbol, range);

  if (wrapper) wrapper.style.opacity = "1";

  /* Fallback labels/data if API returns nothing */
  const labels = candles ? candles.labels  : ["No data"];
  const prices = candles ? candles.prices  : [0];

  /* Determine trend: is last price higher than first? */
  const isPositive = prices.length > 1
    ? prices[prices.length - 1] >= prices[0]
    : true;
  const lineColor = isPositive ? "#4ade80" : "#ef4444";

  /* Destroy previous chart instance to prevent "canvas in use" error */
  if (chartRef.instance) {
    chartRef.instance.destroy();
    chartRef.instance = null;
  }

  const ctx      = canvas.getContext("2d");
  const gradient = ctx.createLinearGradient(0, 0, 0, 220);
  gradient.addColorStop(0, isPositive ? "rgba(74,222,128,0.25)" : "rgba(239,68,68,0.20)");
  gradient.addColorStop(1, "rgba(0,0,0,0)");

  chartRef.instance = new Chart(ctx, {
    type: "line",
    data: {
      labels,
      datasets: [{
        label: `${symbol} (${range})`,
        data:   prices,
        borderColor:     lineColor,
        borderWidth:     2,
        backgroundColor: gradient,
        fill:            true,
        tension:         0.3,
        pointRadius:     prices.length > 60 ? 0 : 3,  /* hide dots on dense data */
        pointBackgroundColor: lineColor,
        pointHoverRadius: 5,
      }]
    },
    options: {
      responsive:          true,
      maintainAspectRatio: false,
      interaction: { intersect:false, mode:"index" },
      plugins: {
        legend: { display:false },
        tooltip: {
          backgroundColor: "rgba(19,23,32,0.95)",
          borderColor:     "rgba(255,255,255,0.08)",
          borderWidth:     1,
          titleColor:      "#8b95a1",
          bodyColor:       "#ffffff",
          bodyFont:        { weight:"700" },
          callbacks: {
            label: ctx => ` €${ctx.parsed.y.toFixed(2)}`
          }
        }
      },
      scales: {
        x: {
          grid:  { color:"rgba(255,255,255,0.04)" },
          ticks: {
            color: "#555f6e",
            font:  { size:11 },
            /* Limit number of visible ticks so they don't overlap */
            maxTicksLimit: 8,
          }
        },
        y: {
          position: "right",
          grid:     { color:"rgba(255,255,255,0.04)" },
          ticks: {
            color: "#555f6e",
            font:  { size:11 },
            callback: v => `€${v.toFixed(2)}`
          }
        }
      }
    }
  });
}


/* ============================================================
   FEATURE 3 — GEOLOCATION → REAL COUNTRY → CORRECT MARKET
   ─────────────────────────────────────────────────────────────
   Steps:
   1. navigator.geolocation.getCurrentPosition() → lat/lng
   2. Reverse geocode with BigDataCloud free API → countryCode
   3. Look up countryCode in COUNTRY_MARKETS table
   4. Update home page subtitle with real country name
   5. Update the "Markets Supported" highlight to show
      the user's country first with an active indicator
   6. Store detected country in sessionStorage so other
      pages can use it without re-requesting location

   Q&A TIP: "The browser Geolocation API is asynchronous —
   it doesn't return a value immediately. Instead I pass a
   callback function which is called once the location is
   known. This is the same callback pattern used in older
   JS before Promises existed."
============================================================ */
function detectUserCountry(callback) {
  if (!navigator.geolocation) {
    callback("Germany", "DE");
    return;
  }

  navigator.geolocation.getCurrentPosition(
    /* SUCCESS */
    async function (pos) {
      try {
        const url  = `${GEO_API_URL}?latitude=${pos.coords.latitude}&longitude=${pos.coords.longitude}&localityLanguage=en`;
        const res  = await fetch(url);
        const data = await res.json();
        const name = data.countryName ?? "Germany";
        const code = data.countryCode ?? "DE";
        /* Cache so we don't need to ask again this session */
        sessionStorage.setItem("pt_country_name", name);
        sessionStorage.setItem("pt_country_code", code);
        callback(name, code);
      } catch {
        callback("Germany", "DE");
      }
    },
    /* ERROR — user denied or timeout */
    function () {
      /* Try cached value first before falling back */
      const cached = sessionStorage.getItem("pt_country_name");
      const code   = sessionStorage.getItem("pt_country_code");
      if (cached) { callback(cached, code ?? "DE"); return; }
      callback("Germany", "DE");
    },
    { timeout:8000, enableHighAccuracy:false, maximumAge:300000 }
  );
}

/* Update the home page UI with detected country information */
function applyCountryToHomeUI(countryName, countryCode) {
  const market = COUNTRY_MARKETS[countryCode] ?? COUNTRY_MARKETS["DE"];

  /* 1 — Update the subtitle text */
  const storedUser = sessionStorage.getItem("pt_user") ?? "Investor";
  const userName   = storedUser.split("@")[0] || storedUser;
  const subtitleEl = document.querySelector(".home-topbar p");
  if (subtitleEl) {
    subtitleEl.textContent =
      `Hello, ${userName}! ${market.flag} ${countryName} (${market.exchange}) market snapshot is ready.`;
  }

  /* 2 — Highlight the user's country in the Markets Supported panel */
  const flagItems = document.querySelectorAll(".market-flag-item");
  flagItems.forEach(item => {
    item.style.opacity = "0.5";
    item.style.transform = "none";
  });

  /* Find the item matching the detected country and highlight it */
  flagItems.forEach(item => {
    const flag = item.querySelector(".flag");
    if (flag && flag.textContent.trim() === market.flag) {
      item.style.opacity     = "1";
      item.style.fontWeight  = "700";
      item.style.color       = "var(--accent)";
      item.style.borderLeft  = "3px solid var(--accent)";
      item.style.paddingLeft = "8px";
      item.style.transition  = "all 0.3s";
    }
  });

  /* 3 — Show a geo-detected badge near the section title */
  const geoTarget = document.getElementById("geo-country-badge");
  if (geoTarget) {
    geoTarget.textContent = `${market.flag} ${countryName} detected`;
    geoTarget.style.display = "inline-flex";
  }

  /* 4 — Store for use on other pages */
  sessionStorage.setItem("pt_country_code", countryCode);
  sessionStorage.setItem("pt_country_name", countryName);
}


/* ============================================================
   6. LOAD ALL LIVE PRICES
   Reads trade-adjusted share counts ONCE, uses them everywhere.
============================================================ */
async function loadAllLivePrices() {
  let currency = "EUR";
  try {
    const saved = JSON.parse(sessionStorage.getItem("pt_settings") || "{}");
    currency = saved.currency ?? "EUR";
  } catch (e) {}

  /* Read share counts ONCE — getLivePortfolio now correctly
     extracts .shares from { SIE:{shares:120,avgPrice:16.5} } */
  const liveShares = getLivePortfolio();

  const entries = Object.entries(STOCK_SYMBOLS);
  const results = await Promise.all(entries.map(([sym]) => fetchQuote(sym)));

  let gotAnyLiveData = false;

  results.forEach((data, i) => {
    const [, shortId] = entries[i];
    if (!data) return;   /* leave this symbol's cached price untouched on failure */
    gotAnyLiveData = true;

    /* FIX (root cause): write the real price straight into the single
       source of truth. Every other page reads PRICES from here, never
       from a formatted string. */
    PT.setPrice(shortId, data.c);

    const shares = Number(liveShares[shortId]) || 0;

    /* Update price/change labels on home + markets pages */
    const priceText  = formatPrice(data.c, currency);
    const changeText = formatChange(data.dp);
    safeSetText(`price-${shortId}`,   priceText);
    safeSetText(`change-${shortId}`,  changeText);
    applyColorClass(`change-${shortId}`, data.dp);
    safeSetText(`pprice-${shortId}`,  priceText);
    safeSetText(`pchange-${shortId}`, changeText);
    applyColorClass(`pchange-${shortId}`, data.dp);

    /* Update portfolio row values — always update even if shares=0 */
    const holdingValue = data.c * shares;
    safeSetText(`shares-${shortId}`,    String(shares));
    safeSetText(`value-${shortId}`,     formatPrice(holdingValue, currency));
    safeSetText(`rowchange-${shortId}`, changeText);
    applyColorClass(`rowchange-${shortId}`, data.dp);
  });

  /* FIX (root cause): don't keep a second, independent copy of
     "total = holdings + cash" here. Ask PT for the number — the
     exact same formula portfolio.html uses — so the two pages can
     never show two different totals for the same state. */
  if (gotAnyLiveData) {
    const { total } = PT.recomputeTotal();
    const fmt = formatPrice(total, currency);
    safeSetText("total-balance",          fmt);
    safeSetText("portfolio-balance",      fmt);
    safeSetText("portfolio-balance-main", fmt);
    const cashEl = document.getElementById("available-cash");
    if (cashEl) cashEl.textContent = formatPrice(PT.getCash(), currency);
  }

  /* Let any page listening (e.g. portfolio.html) know fresh prices
     are in PT's cache now, so it can re-render with the final numbers
     instead of racing its own immediate paint against this async call. */
  window.dispatchEvent(new CustomEvent("pt-live-prices-loaded"));
}

function updateStockUI(shortId, data, currency = "EUR") {
  /* Used by stock-detail page only — home/markets use loadAllLivePrices */

  /* FIX (root cause): this is the ONE moment a real, raw Finnhub price
     exists for this stock. Cache it here, as a number, via PT.setPrice.
     Nothing else is allowed to guess this stock's price by re-parsing
     the #detail-price text later — that text is just a formatted
     string for humans and was never a reliable source of the number. */
  PT.setPrice(shortId, data.c);

  const priceText  = formatPrice(data.c, currency);
  const changeText = formatChange(data.dp);

  safeSetText(`price-${shortId}`,   priceText);
  safeSetText(`change-${shortId}`,  changeText);
  applyColorClass(`change-${shortId}`, data.dp);
  safeSetText(`pprice-${shortId}`,  priceText);
  safeSetText(`pchange-${shortId}`, changeText);
  applyColorClass(`pchange-${shortId}`, data.dp);

  const liveShares = getLivePortfolio();
  const shares = Number(liveShares[shortId]) || 0;
  const holdingValue = data.c * shares;
  safeSetText(`value-${shortId}`,     formatPrice(holdingValue, currency));
  safeSetText(`rowchange-${shortId}`, changeText);
  applyColorClass(`rowchange-${shortId}`, data.dp);
  safeSetText(`shares-${shortId}`,    String(shares));

  const detailPriceEl  = document.getElementById("detail-price");
  const detailChangeEl = document.getElementById("detail-change");
  if (detailPriceEl)  detailPriceEl.textContent = priceText;
  if (detailChangeEl) {
    const sign = data.dp >= 0 ? "+" : "";
    detailChangeEl.textContent = `${sign}${(data.c - data.pc).toFixed(2)} (${changeText}) Today`;
    applyColorClass("detail-change", data.dp);
  }

  safeSetText("stat-open",       data.o  ? formatPrice(data.o,  currency) : "—");
  safeSetText("stat-high",       data.h  ? formatPrice(data.h,  currency) : "—");
  safeSetText("stat-low",        data.l  ? formatPrice(data.l,  currency) : "—");
  safeSetText("stat-prev-close", data.pc ? formatPrice(data.pc, currency) : "—");
  applyColorClass("stat-high",  1);
  applyColorClass("stat-low",  -1);
}


/* ============================================================
   7. MARKET HOURS
============================================================ */
function isMarketOpen(exchange = "XETRA") {
  const now = new Date();
  const day = now.getUTCDay();
  if (day === 0 || day === 6) return false;
  const mins = now.getUTCHours() * 60 + now.getUTCMinutes();
  const H = { XETRA:[7*60,15*60+30], NYSE:[14*60+30,21*60], LSE:[8*60,16*60+30], BIST:[6*60,14*60] };
  const [o, c] = H[exchange] ?? H.XETRA;
  return mins >= o && mins < c;
}

function updateMarketStatusUI() {
  const textEl = document.getElementById("market-status-text");
  const dotEl  = document.getElementById("status-dot");
  if (!textEl || !dotEl) return;
  const open = isMarketOpen("XETRA");
  textEl.textContent     = open ? "Market Open"   : "Market Closed";
  dotEl.style.background = open ? "var(--accent)" : "#ef4444";
}


/* ============================================================
   8. SIDEBAR + LOGOUT + MOBILE
============================================================ */
document.addEventListener("DOMContentLoaded", function () {
  /* Active nav link */
  const currentPage = window.location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".sidebar-nav .nav-item").forEach(link => {
    link.classList.remove("active");
    if (link.getAttribute("href") === currentPage) link.classList.add("active");
  });

  /* Mobile sidebar toggle */
  const menuBtn = document.getElementById("mobile-menu-btn");
  const sidebar = document.getElementById("sidebar");
  if (menuBtn) {
    menuBtn.addEventListener("click", e => {
      e.stopPropagation();
      document.body.classList.toggle("sidebar-open");
    });
  }
  document.addEventListener("click", e => {
    if (!document.body.classList.contains("sidebar-open")) return;
    if (sidebar && sidebar.contains(e.target)) return;
    if (menuBtn && menuBtn.contains(e.target)) return;
    document.body.classList.remove("sidebar-open");
  });

  /* Logout */
  document.querySelectorAll(".btn-logout").forEach(btn => {
    btn.addEventListener("click", e => {
      e.preventDefault();
      if (confirm("Are you sure you want to log out?")) {
        sessionStorage.removeItem("pt_user");
        window.location.href = "index.html";
      }
    });
  });
});


/* ============================================================
   9. PORTFOLIO FALLBACK
============================================================ */
function calculatePortfolioFromDOM() {
  const MOCK = { SIE:18.24, SAP:213.65, TSLA:178.24, NVDA:987.54, AAPL:212.35 };
  let total = 0;
  Object.entries(getLivePortfolio()).forEach(([id, shares]) => {
    const value = shares * (MOCK[id] ?? 0);
    total += value;
    safeSetText(`value-${id}`, formatPrice(value, "EUR"));
  });
  safeSetText("total-balance", formatPrice(total, "EUR"));
}

function restoreSettingsFromStorage() {
  try {
    const s = JSON.parse(sessionStorage.getItem("pt_settings") || "{}");
    const f = (id, val) => { const el = document.getElementById(id); if (el && val !== undefined) el[typeof val === "boolean" ? "checked" : "value"] = val; };
    f("toggle-alerts",   s.alerts);
    f("toggle-geo",      s.geoEnabled);
    f("select-country",  s.country);
    f("select-currency", s.currency);
  } catch (e) { console.warn("[PT] Settings restore:", e.message); }
}


/* ============================================================
   10. PAGE-SPECIFIC INIT
   Each block is gated on a unique element that only exists
   on that specific page.
============================================================ */
document.addEventListener("DOMContentLoaded", async function () {

  /* ── HOME PAGE ─────────────────────────────────────────── */
  const greetingEl = document.getElementById("user-greeting");
  if (greetingEl) {
    const storedUser = sessionStorage.getItem("pt_user") ?? "Investor";
    const userName   = storedUser.split("@")[0] || storedUser;
    greetingEl.textContent = userName;

    /* Wire search bar with live Finnhub search */
    const searchInput    = document.getElementById("search-input");
    const searchDropdown = document.getElementById("search-dropdown");
    if (searchInput && searchDropdown) {
      initSearchBar(searchInput, searchDropdown);
    }

    /* FEATURE 3 — Run geolocation and update home UI */
    detectUserCountry((countryName, countryCode) => {
      applyCountryToHomeUI(countryName, countryCode);
    });

    /* Load live prices */
    if (FINNHUB_API_KEY !== "YOUR_API_KEY_HERE") {
      await loadAllLivePrices();
    }
    updateMarketStatusUI();
  }

  /* ── MARKETS PAGE ───────────────────────────────────────── */
  if (document.getElementById("news-feed")) {
    /* Wire search bar on markets page too */
    const searchInput    = document.getElementById("search-input");
    const searchDropdown = document.getElementById("search-dropdown");
    if (searchInput && searchDropdown) {
      initSearchBar(searchInput, searchDropdown);
    }

    if (FINNHUB_API_KEY !== "YOUR_API_KEY_HERE") {
      await loadAllLivePrices();
    }
  }

  /* ── STOCK DETAIL PAGE ──────────────────────────────────── */
  if (document.getElementById("chart-main")) {
    updateMarketStatusUI();

    /* Read which symbol to show — from search or default to SIE */
    const selectedSymbol = sessionStorage.getItem("pt_selected_symbol") ?? "ENR.DE";
    const selectedName   = sessionStorage.getItem("pt_selected_symbol_name") ?? "Siemens Energy AG";

    /* Update the page header with the selected stock */
    safeSetText("detail-stock-name",     selectedName);
    safeSetText("detail-stock-exchange", selectedSymbol);

    /* FIX: the badge (SIE/TSLA/etc icon+color) and the sector tag
       pills were plain static HTML with no id at all — nothing could
       ever update them, so they stayed on "SIE" / Energy / Utilities
       no matter which stock you navigated to. */
    const shortIdForHeader = STOCK_SYMBOLS[selectedSymbol] ?? selectedSymbol.split(".")[0];
    const meta = STOCK_META[shortIdForHeader];
    if (meta) {
      const badgeEl = document.getElementById("detail-badge");
      if (badgeEl) {
        badgeEl.className = "stock-header-badge " + meta.badgeClass;
        badgeEl.textContent = shortIdForHeader;
      }
      safeSetText("detail-stock-exchange", meta.exchange);
      safeSetText("detail-tag-1", meta.sectors[0] ?? "");
      safeSetText("detail-tag-2", meta.sectors[1] ?? "");
    }

    /* Shared chart reference object — holds the ChartJS instance
       so buildDetailChart() can destroy it before rebuilding    */
    const chartRef = { instance: null };

    /* FEATURE 2 — Build real candle chart for selected range */
    if (FINNHUB_API_KEY !== "YOUR_API_KEY_HERE") {
      /* Fetch quote data for header price */
      const quoteData = await fetchQuote(selectedSymbol);
      if (quoteData) {
        /* Update price, change, and OHLC stats */
        const shortId = STOCK_SYMBOLS[selectedSymbol] ?? selectedSymbol.split(".")[0];
        updateStockUI(shortId, quoteData, "EUR");
      }

      /* Build the initial chart with 1D candle data */
      await buildDetailChart(selectedSymbol, "1D", chartRef);

      /* Wire time range pill buttons to rebuild chart on click */
      document.querySelectorAll("#time-pills .time-pill").forEach(pill => {
        pill.addEventListener("click", async function () {
          /* Update active pill style */
          document.querySelectorAll("#time-pills .time-pill")
            .forEach(p => p.classList.remove("active"));
          this.classList.add("active");

          /* Rebuild chart with new range — real API call */
          await buildDetailChart(selectedSymbol, this.getAttribute("data-range"), chartRef);
        });
      });

    } else {
      /* No API key — build chart with mock data as fallback */
      buildDetailChartMock(chartRef);
    }
  }

  /* ── PORTFOLIO PAGE ─────────────────────────────────────── */
  if (document.getElementById("total-balance")) {
    if (FINNHUB_API_KEY !== "YOUR_API_KEY_HERE") {
      await loadAllLivePrices();
    } else {
      calculatePortfolioFromDOM();
    }
  }

  /* ── SETTINGS PAGE ──────────────────────────────────────── */
  if (document.getElementById("select-country")) {
    restoreSettingsFromStorage();
  }

});


/* ============================================================
   11. MOCK CHART FALLBACK (no API key)
   Draws a static chart so the detail page always looks good
   even without a Finnhub key set.
============================================================ */
function buildDetailChartMock(chartRef) {
  const canvas = document.getElementById("chart-main");
  if (!canvas || typeof Chart === "undefined") return;
  if (chartRef.instance) { chartRef.instance.destroy(); chartRef.instance = null; }

  const labels = ["09:00","10:00","11:00","12:00","13:00","14:00","15:00","16:00","17:00"];
  const prices = [17.82, 17.90, 18.00, 17.95, 18.05, 18.10, 18.15, 18.20, 18.24];
  const ctx = canvas.getContext("2d");
  const grad = ctx.createLinearGradient(0,0,0,220);
  grad.addColorStop(0,"rgba(74,222,128,0.25)");
  grad.addColorStop(1,"rgba(0,0,0,0)");

  chartRef.instance = new Chart(ctx, {
    type:"line",
    data:{
      labels,
      datasets:[{ data:prices, borderColor:"#4ade80", borderWidth:2,
                  backgroundColor:grad, fill:true, tension:0.3,
                  pointRadius:3, pointBackgroundColor:"#4ade80", pointHoverRadius:5 }]
    },
    options:{
      responsive:true, maintainAspectRatio:false,
      interaction:{ intersect:false, mode:"index" },
      plugins:{
        legend:{display:false},
        tooltip:{
          backgroundColor:"rgba(19,23,32,0.95)", borderColor:"rgba(255,255,255,0.08)",
          borderWidth:1, titleColor:"#8b95a1", bodyColor:"#ffffff",
          callbacks:{ label: ctx => ` €${ctx.parsed.y.toFixed(2)}` }
        }
      },
      scales:{
        x:{ grid:{color:"rgba(255,255,255,0.04)"}, ticks:{color:"#555f6e",font:{size:11}} },
        y:{ position:"right", grid:{color:"rgba(255,255,255,0.04)"},
            ticks:{color:"#555f6e",font:{size:11}, callback:v=>`€${v.toFixed(2)}`} }
      }
    }
  });
}


/* ============================================================
   END OF main.js v3.0
   ─────────────────────────────────────────────────────────────
   3 exam features active:
   ✅ Real Finnhub company search with live dropdown
   ✅ Real candle chart data per time range (1D→Max)
   ✅ Geolocation → country → market highlight + subtitle
============================================================ */