/* Tienda MJ ICED — catálogo público. Lee productos, packs y ajustes desde Supabase. */
(() => {
  const cfg = window.VVS_CONFIG || {};
  let phone = (cfg.whatsapp || '').replace(/\D/g, '');
  const db = cfg.supabaseUrl && cfg.supabaseAnonKey && window.supabase
    ? window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey) : null;

  const $ = s => document.querySelector(s);
  const $$ = s => [...document.querySelectorAll(s)];
  const money = v => new Intl.NumberFormat('es-CL', { style: 'currency', currency: 'CLP', maximumFractionDigits: 0 }).format(Number(v) || 0);
  const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ESC[c]);
  const wa = text => phone ? `https://wa.me/${phone}?text=${encodeURIComponent(text)}` : 'https://wa.me/';
  const openWA = text => window.open(wa(text), '_blank', 'noopener');

  // Datos de ejemplo: solo se usan si la tienda NO está conectada a Supabase.
  const demoProducts = [
    { id: 'square', name: 'Aros Moissanita Cuadrados', category: 'Aros', price: 14990, description: 'Un diseño limpio y brillante, fácil de combinar.', image_url: 'assets/aros-cuadrados.jpg', stock: 1 },
    { id: 'round', name: 'Aros Moissanita Redondos', category: 'Aros', price: 13990, description: 'Un clásico discreto para usar cualquier día.', image_url: 'assets/aros-redondos.jpg', stock: 1 }
  ];
  const demoPacks = [{ id: 'duo', name: 'Pack Dúo VVS', description: 'Lleva ambos diseños en una sola compra.', price: 24990, original_price: 28980, image_url: 'assets/pack-duo.jpg' }];

  const finalPrice = p => (Number(p.promo_price) > 0 && Number(p.promo_price) < Number(p.price)) ? Number(p.promo_price) : Number(p.price);
  const isVVS = p => /vvs|moissanita|moissanite/i.test(`${p.category || ''} ${p.name || ''} ${p.description || ''}`);

  /* ---------- Tarjetas ---------- */
  function productCard(p) {
    const shown = finalPrice(p), onSale = shown < Number(p.price);
    const tag = p.promo_label ? esc(p.promo_label) : onSale ? 'OFERTA' : Number(p.stock) <= 2 ? 'Pocas unidades' : '';
    const img = p.image_url
      ? `<img src="${esc(p.image_url)}" alt="${esc(p.name)}" loading="lazy" onerror="this.outerHTML='<div class=&quot;no-photo&quot;>VVS</div>'">`
      : '<div class="no-photo">MJ</div>';
    return `<article class="product"><div class="product-image">${img}${tag ? `<span class="tag">${tag}</span>` : ''}</div>
      <div class="info"><div class="category">${esc(p.category || 'Selección VVS')}</div>
      <div class="titleprice"><h3>${esc(p.name)}</h3><span class="price">${money(shown)}${onSale ? ` <del class="old">${money(p.price)}</del>` : ''}</span></div>
      <p class="desc">${esc(p.description || 'Consulta detalles de esta pieza por WhatsApp.')}</p>
      <button class="buy" data-product="${esc(p.id)}">Ver detalles ↗</button></div></article>`;
  }
  function packCard(k) {
    return `<article class="pack">${k.image_url ? `<img src="${esc(k.image_url)}" alt="${esc(k.name)}" onerror="this.style.display='none'">` : ''}
      <h3>${esc(k.name)}</h3><p>${esc(k.description || 'Consulta disponibilidad y detalles.')}</p>
      <span class="packprice">${money(k.price)}</span>${k.original_price ? `<span class="old">${money(k.original_price)}</span>` : ''}
      <p><button data-pack="${esc(k.id)}">Consultar pack ↗</button></p></article>`;
  }

  /* ---------- Personalización (panel admin) ---------- */
  const DEFAULTS = { brand_name: 'JEWELRY', hero_title: 'El detalle que cambia todo.', collection_title: 'Piezas para llevar a tu manera.', collection_text: 'Una buena pieza no necesita llamar la atención todo el tiempo. Solo tiene que sentirse tuya.', packs_title: 'Los favoritos, juntos.', about_title: 'El lujo también está en lo simple.' };
  const loadFonts = fonts => {
    const fam = [...new Set(fonts.filter(Boolean))].map(f => 'family=' + encodeURIComponent(f).replace(/%20/g, '+') + ':wght@400;500;600;700');
    if (!fam.length) return;
    const l = document.createElement('link'); l.rel = 'stylesheet'; l.href = `https://fonts.googleapis.com/css2?${fam.join('&')}&display=swap`; document.head.appendChild(l);
  };
  const setWA = () => $$('.wa').forEach(el => el.href = wa('Hola MJ ICED, quisiera consultar por sus piezas disponibles.'));

  function applySettings(s) {
    const root = document.documentElement.style;
    root.setProperty('--gold', s.accent_color || '#c6a56a');
    root.setProperty('--paper', s.background_color || '#f6f4ef');
    root.setProperty('--ink', s.text_color || '#1b1916');
    root.setProperty('--dark', s.dark_color || '#171512');
    if (s.heading_font && s.heading_font !== 'Playfair Display') { loadFonts([s.heading_font]); root.setProperty('--serif', `'${s.heading_font}',Georgia,serif`); }
    if (s.body_font && s.body_font !== 'DM Sans') { loadFonts([s.body_font]); root.setProperty('--sans', `'${s.body_font}',Arial,sans-serif`); }
    document.body.classList.remove('btn-rounded', 'btn-pill');
    if (s.button_style === 'rounded') document.body.classList.add('btn-rounded');
    if (s.button_style === 'pill') document.body.classList.add('btn-pill');

    const text = (sel, v) => { const el = $(sel); if (el && v) el.textContent = v; };
    const title = (sel, key) => { const el = $(sel), v = s[key]; if (el && v && v !== DEFAULTS[key]) el.innerHTML = esc(v).replace(/\n/g, '<br>'); };
    const toggle = (sel, on) => $$(sel).forEach(el => el.style.display = on === false ? 'none' : '');

    text('.topline', s.topline);
    if (s.brand_name && s.brand_name !== DEFAULTS.brand_name) $$('.brand > span:last-child').forEach(el => el.textContent = s.brand_name);
    else if (s.logo_url && s.brand_name === '') $$('.brand > span:last-child').forEach(el => el.style.display = 'none');
    if (s.logo_url) $$('.brand .mark').forEach(m => { m.innerHTML = `<img src="${esc(s.logo_url)}" alt="${esc(s.brand_name || 'Logo')}">`; m.classList.add('has-logo'); });
    text('.hero .eyebrow', s.hero_eyebrow);
    title('.hero h1', 'hero_title');
    text('.lead', s.hero_subtitle);
    if (s.hero_button) text('.hero .goldbtn', s.hero_button + ' ↓');
    if (s.hero_image) { const img = $('.hero-art img'); if (img) { img.src = s.hero_image; img.style.display = 'block'; img.nextElementSibling.style.display = 'none'; } }
    [1, 2, 3].forEach(n => {
      text(`.values > div:nth-child(${n}) strong`, s[`value${n}_title`]);
      text(`.values > div:nth-child(${n}) small`, s[`value${n}_text`]);
    });
    title('.sectionhead h2', 'collection_title');
    if (s.collection_text && s.collection_text !== DEFAULTS.collection_text) text('.sectionhead > p', s.collection_text);
    title('.packs h2', 'packs_title');
    text('.packs > div:first-child > p:not(.eyebrow)', s.packs_text);
    title('.about h2', 'about_title');
    text('.aboutgrid > div p:nth-child(1)', s.about_text1);
    text('.aboutgrid > div p:nth-child(2)', s.about_text2);
    if (s.about_image) { const im = $('#aboutPhoto'); im.src = s.about_image; im.hidden = false; }
    text('.foot-brand p', s.footer_text);
    text('.contact h2', s.contact_text);
    if (s.contact_button) text('.contact .goldbtn', s.contact_button + ' ↗');
    if (s.instagram_url) { const ig = $('.footer-ig'); ig.href = s.instagram_url; ig.hidden = false; }
    toggle('.values', s.show_values);
    toggle('#packs-section, nav a[href="#packs-section"]', s.show_packs);
    toggle('#marca, nav a[href="#marca"]', s.show_about);
    const num = String(s.whatsapp || '').replace(/\D/g, '');
    if (num) { phone = num; setWA(); }
  }

  /* ---------- Datos ---------- */
  const PRODUCT_COLS = 'id,name,category,price,promo_price,promo_label,description,image_url,stock,active';
  const BASIC_COLS = 'id,name,category,price,description,image_url,stock,active';
  const fetchProducts = async () => {
    const q = cols => db.from('products').select(cols).eq('active', true).order('created_at', { ascending: false });
    let r = await q(PRODUCT_COLS);
    if (r.error) { console.warn('Reintentando sin columnas de oferta:', r.error.message); r = await q(BASIC_COLS); }
    return r;
  };

  let products = [], packs = [], gallery = {};

  async function load() {
    let failed = false;
    if (db) ['#products-vvs', '#products-circonita'].forEach(g => $(g).innerHTML = '<div class="skeleton"></div>'.repeat(3));
    if (!db) { products = demoProducts; packs = demoPacks; }
    else {
      try {
        const [p, k, st, gi] = await Promise.all([
          fetchProducts(),
          db.from('packs').select('id,name,description,price,original_price,image_url,active').eq('active', true).order('created_at', { ascending: false }),
          db.from('store_settings').select('*').eq('id', 1).maybeSingle(),
          db.from('product_images').select('product_id,image_url,sort_order').order('sort_order')
        ]);
        if (p.error) { failed = true; console.error('Productos:', p.error.message); } else products = (p.data || []).filter(x => Number(x.stock) > 0);
        if (k.error) console.error('Packs:', k.error.message); else packs = k.data || [];
        if (!gi.error) (gi.data || []).forEach(im => (gallery[im.product_id] ??= []).push(im.image_url));
        if (!st.error && st.data) applySettings(st.data);
      } catch (e) { failed = true; console.error('No se pudo conectar con Supabase:', e); }
    }
    render(failed);
  }

  function render(failed) {
    const group = (items, grid, count) => {
      $(grid).innerHTML = failed
        ? '<p class="loading">No pudimos cargar las piezas. Actualiza la página en unos minutos.</p>'
        : items.length ? items.map(productCard).join('') : '<p class="loading">Aún no hay piezas disponibles en esta colección.</p>';
      $(count).textContent = failed ? 'COLECCIÓN' : `${String(items.length).padStart(2, '0')} PIEZA${items.length === 1 ? '' : 'S'}`;
    };
    group(products.filter(isVVS), '#products-vvs', '#count-vvs');
    group(products.filter(p => !isVVS(p)), '#products-circonita', '#count-circonita');
    $('#packs').innerHTML = packs.length ? packs.map(packCard).join('') : '<div class="packfallback"><span>MJ</span><p>Pronto anunciaremos nuevas combinaciones.</p></div>';
    revealSoon();
  }

  /* ---------- Detalle de producto ---------- */
  let imgs = [], idx = 0, modal;
  function buildModal() {
    modal = document.createElement('div');
    modal.id = 'productDetailModal';
    modal.className = 'product-detail-overlay';
    modal.innerHTML = `<div class="product-detail" role="dialog" aria-modal="true"><button class="detail-close" aria-label="Cerrar">×</button>
      <div class="detail-gallery"><button class="gallery-arrow prev" aria-label="Imagen anterior">‹</button><img class="detail-main-image" alt=""><button class="gallery-arrow next" aria-label="Imagen siguiente">›</button><div class="detail-thumbs"></div></div>
      <div class="detail-copy"><p class="detail-category"></p><h2 class="detail-name"></h2><div class="detail-price"></div><p class="detail-description"></p><p class="detail-stock"></p><button class="detail-whatsapp">Consultar por WhatsApp ↗</button></div></div>`;
    document.body.appendChild(modal);
    const close = () => modal.classList.remove('open');
    modal.querySelector('.detail-close').onclick = close;
    modal.addEventListener('click', e => { if (e.target === modal) close(); });
    modal.querySelector('.prev').onclick = () => step(-1);
    modal.querySelector('.next').onclick = () => step(1);
    document.addEventListener('keydown', e => { if (e.key === 'Escape') close(); });
  }
  function step(d) { if (imgs.length > 1) { idx = (idx + d + imgs.length) % imgs.length; paintImage(); } }
  function paintImage() {
    const main = modal.querySelector('.detail-main-image');
    main.src = imgs[idx] || '';
    main.style.display = imgs.length ? 'block' : 'none';
    modal.querySelector('.prev').hidden = modal.querySelector('.next').hidden = imgs.length < 2;
    modal.querySelector('.detail-thumbs').innerHTML = imgs.map((s, i) => `<button class="detail-thumb ${i === idx ? 'active' : ''}" data-thumb="${i}"><img src="${esc(s)}" alt="Fotografía ${i + 1}"></button>`).join('');
  }
  function showDetail(p) {
    if (!modal) buildModal();
    imgs = gallery[p.id]?.length ? gallery[p.id] : [p.image_url].filter(Boolean);
    idx = 0;
    const shown = finalPrice(p);
    modal.querySelector('.detail-category').textContent = p.category || 'Colección';
    modal.querySelector('.detail-name').textContent = p.name;
    modal.querySelector('.detail-price').innerHTML = shown < Number(p.price) ? `${money(shown)} <del>${money(p.price)}</del>` : money(shown);
    modal.querySelector('.detail-description').textContent = p.description || 'Consulta los detalles de esta pieza.';
    modal.querySelector('.detail-stock').textContent = Number(p.stock) <= 2 ? `Disponibilidad: ${p.stock} unidad(es)` : 'Disponible';
    modal.querySelector('.detail-whatsapp').onclick = () => openWA(`Hola MJ ICED, me interesa "${p.name}" por ${money(shown)}. ¿Me confirman disponibilidad y detalles?`);
    paintImage();
    modal.classList.add('open');
  }

  /* ---------- Efectos ---------- */
  const io = 'IntersectionObserver' in window ? new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } }), { threshold: .12 }) : null;
  function revealSoon() {
    if (!io) return;
    $$('.product,.pack,.step,.values>div,.sectionhead,.category-heading,.aboutgrid,.faq details,.contact>*').forEach((el, i) => {
      if (el.classList.contains('reveal')) return;
      el.style.transitionDelay = `${(i % 4) * 70}ms`; el.classList.add('reveal'); io.observe(el);
    });
  }
  const header = $('#top');
  const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 8);
  window.addEventListener('scroll', onScroll, { passive: true }); onScroll();

  /* ---------- Inicio ---------- */
  setWA();
  $('#year').textContent = new Date().getFullYear();
  $('#menu').onclick = () => { const o = $('#nav').classList.toggle('open'); $('#menu').setAttribute('aria-expanded', o); };
  $$('nav a').forEach(a => a.addEventListener('click', () => $('#nav').classList.remove('open')));

  document.addEventListener('click', e => {
    const buy = e.target.closest('[data-product]');
    if (buy) { const p = products.find(x => String(x.id) === buy.dataset.product); if (p) showDetail(p); return; }
    const pk = e.target.closest('[data-pack]');
    if (pk) { const k = packs.find(x => String(x.id) === pk.dataset.pack); if (k) openWA(`Hola MJ ICED, me interesa el pack "${k.name}" por ${money(k.price)}. ¿Me confirman qué incluye y disponibilidad?`); return; }
    const th = e.target.closest('[data-thumb]');
    if (th && modal) { idx = +th.dataset.thumb; paintImage(); }
  });

  revealSoon();
  load();
})();
