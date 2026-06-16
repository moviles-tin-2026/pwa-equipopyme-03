let DATABASE = [
  { id: 1, nombre: "Camisa Lino Pure", precio: 49.99, stock: 12, icono: "👔" },
  { id: 2, nombre: "Jeans Oversized Oasis", precio: 65.00, stock: 8, icono: "👖" },
  { id: 3, nombre: "Vestido Knit Clarity", precio: 89.95, stock: 5, icono: "👗" },
  { id: 4, nombre: "Chaqueta Canvas Minimal", precio: 120.00, stock: 3, icono: "🧥" }
];

let CARRITO = {};
let TOTAL_VENTAS_CLOUD = 0.00;
let TOTAL_UNIDADES_CLOUD = 0;

window.addEventListener("DOMContentLoaded", () => {
  renderizarModuloVentas();
  renderizarModuloInventario();
});

function manejarLogin(event) {
  event.preventDefault();
  document.getElementById("mod-auth").classList.add("hidden");
  document.getElementById("mod-ventas").classList.remove("hidden");
  document.getElementById("app-nav").classList.remove("hidden");
}

function cerrarSesion() {
  document.getElementById("app-nav").classList.add("hidden");
  document.getElementById("mod-ventas").classList.add("hidden");
  document.getElementById("mod-inventario").classList.add("hidden");
  document.getElementById("mod-admin").classList.add("hidden");
  document.getElementById("mod-auth").classList.remove("hidden");
}

function cambiarModulo(moduloId, boton) {
  document.querySelectorAll(".app-screen").forEach(screen => {
    if(screen.id !== "mod-auth") screen.classList.add("hidden");
  });
  document.querySelectorAll(".nav-item").forEach(item => item.classList.remove("active"));
  
  document.getElementById(`mod-${moduloId}`).classList.remove("hidden");
  boton.classList.add("active");
}

function renderizarModuloVentas() {
  const container = document.getElementById("ventas-container");
  if (!container) return;

  container.innerHTML = DATABASE.map(prod => {
    const cant = CARRITO[prod.id] || 0;
    return `
      <div class="sale-item">
        <div class="item-meta">
          <span class="item-icon">${prod.icono}</span>
          <div>
            <span class="item-name">${prod.nombre}</span>
            <span class="item-price">$${prod.precio.toFixed(2)}</span>
          </div>
        </div>
        <div class="counter-controls">
          <button class="btn-counter" onclick="modificarCarrito(${prod.id}, -1)">-</button>
          <span style="font-weight:700; min-width:20px; text-align:center">${cant}</span>
          <button class="btn-counter" onclick="modificarCarrito(${prod.id}, 1)">+</button>
        </div>
      </div>
    `;
  }).join('');
}

function modificarCarrito(id, cambio) {
  const producto = DATABASE.find(p => p.id === id);
  const cantActual = CARRITO[id] || 0;
  
  if (cambio === 1 && cantActual >= producto.stock) {
    alert(`Almacén insuficiente en la nube (${producto.stock} disponibles).`);
    return;
  }

  CARRITO[id] = Math.max(0, cantActual + cambio);
  if(CARRITO[id] === 0) delete CARRITO[id];

  actualizarContadoresVenta();
  renderizarModuloVentas();
}

function actualizarContadoresVenta() {
  let unidades = 0;
  let dinero = 0;

  Object.keys(CARRITO).forEach(id => {
    const prod = DATABASE.find(p => p.id == id);
    unidades += CARRITO[id];
    dinero += (prod.precio * CARRITO[id]);
  });

  document.getElementById("cart-count").innerText = unidades;
  document.getElementById("cart-total").innerText = dinero.toFixed(2);
}

function procesarVenta() {
  if (Object.keys(CARRITO).length === 0) {
    alert("Agrega artículos al carrito antes de registrar.");
    return;
  }

  Object.keys(CARRITO).forEach(id => {
    const prod = DATABASE.find(p => p.id == id);
    prod.stock -= CARRITO[id];
    TOTAL_VENTAS_CLOUD += (prod.precio * CARRITO[id]);
    TOTAL_UNIDADES_CLOUD += CARRITO[id];
  });

  CARRITO = {};
  actualizarContadoresVenta();
  renderizarModuloVentas();
  renderizarModuloInventario();
  actualizarDashboardAdmin();

  alert("⚙️ ERP Sync: Transacción guardada en base de datos.");
}

function renderizarModuloInventario() {
  const container = document.getElementById("inventario-container");
  if (!container) return;

  container.innerHTML = DATABASE.map(prod => `
    <tr>
      <td style="font-weight: 600">${prod.icono} ${prod.nombre}</td>
      <td><span style="background: rgba(255,255,255,0.05); padding:0.2rem 0.5rem; border-radius:6px">${prod.stock} u.</span></td>
      <td style="color:var(--accent-teal); font-weight:700">$${prod.precio.toFixed(2)}</td>
    </tr>
  `).join('');
}

function abrirModalAgregar() {
  document.getElementById("modal-agregar").classList.add("open");
}

function cerrarModalAgregar() {
  document.getElementById("modal-agregar").classList.remove("open");
  document.getElementById("m-nombre").value = "";
  document.getElementById("m-precio").value = "";
  document.getElementById("m-stock").value = "";
}

function guardarNuevoProducto() {
  const nombre = document.getElementById("m-nombre").value.trim();
  const precio = parseFloat(document.getElementById("m-precio").value);
  const stock = parseInt(document.getElementById("m-stock").value);

  if(!nombre || isNaN(precio) || isNaN(stock) || precio <= 0 || stock < 0) {
    alert("Por favor, llena los campos con valores corporativos válidos.");
    return;
  }

  DATABASE.push({
    id: Date.now(),
    nombre: nombre,
    precio: precio,
    stock: stock,
    icono: "🛍️"
  });

  renderizarModuloVentas();
  renderizarModuloInventario();
  cerrarModalAgregar();
}

function actualizarDashboardAdmin() {
  document.getElementById("metric-ventas").innerText = `$${TOTAL_VENTAS_CLOUD.toFixed(2)}`;
  document.getElementById("metric-unidades").innerText = `${TOTAL_UNIDADES_CLOUD} u.`;
}