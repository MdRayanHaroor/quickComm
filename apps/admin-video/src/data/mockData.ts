// ============================================================
// Mock data for QuickComm Admin Panel demo video
// ============================================================

export const STATS = {
  revenue: 128450,
  orders: 3847,
  riders: 42,
  customers: 9821,
  avgDelivery: 18, // minutes
  satisfaction: 96.4, // %
};

export const ORDERS = [
  { id: "#QC-8821", customer: "Aisha Patel", items: 6, total: 1240, status: "Delivered", time: "10:14 AM" },
  { id: "#QC-8822", customer: "Rahul Sharma", items: 3, total: 680, status: "In Transit", time: "10:22 AM" },
  { id: "#QC-8823", customer: "Priya Nair", items: 8, total: 2100, status: "Preparing", time: "10:31 AM" },
  { id: "#QC-8824", customer: "Mohammed Ali", items: 2, total: 390, status: "Pending", time: "10:45 AM" },
  { id: "#QC-8825", customer: "Sneha Reddy", items: 5, total: 950, status: "Delivered", time: "11:02 AM" },
  { id: "#QC-8826", customer: "Vikram Singh", items: 4, total: 820, status: "In Transit", time: "11:10 AM" },
];

export const STATUS_COLORS: Record<string, string> = {
  Delivered: "#22c55e",
  "In Transit": "#3b82f6",
  Preparing: "#f59e0b",
  Pending: "#94a3b8",
};

export const PRODUCTS = [
  { name: "Organic Whole Milk", category: "Dairy", stock: 84, maxStock: 120, price: 68, image: "🥛" },
  { name: "Basmati Rice 5kg", category: "Grains", stock: 32, maxStock: 100, price: 299, image: "🌾" },
  { name: "Fresh Eggs (12pk)", category: "Dairy", stock: 12, maxStock: 60, price: 120, image: "🥚" },
  { name: "Amul Butter 500g", category: "Dairy", stock: 55, maxStock: 80, price: 250, image: "🧈" },
  { name: "Red Apples 1kg", category: "Fruits", stock: 8, maxStock: 50, price: 180, image: "🍎" },
  { name: "Toor Dal 2kg", category: "Pulses", stock: 70, maxStock: 100, price: 220, image: "🫘" },
];

export const RIDERS = [
  { id: "R01", name: "Arjun K.", status: "Active", deliveries: 12, x: 35, y: 40 },
  { id: "R02", name: "Dev M.", status: "Active", deliveries: 9, x: 60, y: 30 },
  { id: "R03", name: "Kiran P.", status: "Active", deliveries: 14, x: 20, y: 65 },
  { id: "R04", name: "Ravi S.", status: "Break", deliveries: 7, x: 75, y: 55 },
  { id: "R05", name: "Yusuf A.", status: "Active", deliveries: 11, x: 50, y: 70 },
  { id: "R06", name: "Nisha T.", status: "Active", deliveries: 8, x: 45, y: 20 },
];

export const WEEKLY_REVENUE = [45200, 62100, 58900, 71300, 83400, 95700, 128450];
export const WEEK_LABELS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

// TTS Narration script per scene
export const NARRATION = {
  intro: "Introducing QuickComm — your all-in-one supermarket management platform. Built for speed, built for scale.",
  dashboard: "The supermarket dashboard gives you a real-time pulse of your operations — tracking daily GMV, order volume, sales activity trends, and catalog health at a glance.",
  orders: "The live orders pipeline streamlines fulfillment — monitor incoming orders, track preparation, and assign delivery riders with a single click.",
  products: "Full catalog control at your fingertips — search items, monitor stock alerts, toggle instant availability, and manage pricing in real time.",
  fleet: "Fleet tracking maps active riders across your five-kilometer delivery zone in real time, keeping dispatches and customer drop-offs on schedule.",
  settings: "Store settings empower managers to set GPS coordinates, enforce radial delivery boundaries, and customize free delivery rules without code.",
  outro: "QuickComm. Manage everything from one place. Deliver faster. Grow smarter.",
};
