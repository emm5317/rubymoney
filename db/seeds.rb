categories = [
  { name: "Housing",        color: "#4F46E5", icon: "home",          position: 1 },
  { name: "Utilities",      color: "#7C3AED", icon: "bolt",          position: 2 },
  { name: "Groceries",      color: "#059669", icon: "shopping-cart",  position: 3 },
  { name: "Dining",         color: "#D97706", icon: "utensils",      position: 4 },
  { name: "Transport",      color: "#DC2626", icon: "car",           position: 5 },
  { name: "Insurance",      color: "#2563EB", icon: "shield",        position: 6 },
  { name: "Healthcare",     color: "#DB2777", icon: "heart",         position: 7 },
  { name: "Entertainment",  color: "#9333EA", icon: "film",          position: 8 },
  { name: "Subscriptions",  color: "#0891B2", icon: "refresh",       position: 9 },
  { name: "Shopping",       color: "#EA580C", icon: "bag",           position: 10 },
  { name: "Travel",         color: "#0D9488", icon: "plane",         position: 11 },
  { name: "Education",      color: "#4338CA", icon: "book",          position: 12 },
  { name: "Gifts",          color: "#C026D3", icon: "gift",          position: 13 },
  { name: "Income",         color: "#16A34A", icon: "dollar-sign",   position: 14 },
  { name: "Transfers",      color: "#6B7280", icon: "arrows",        position: 15 }
]

categories.each do |attrs|
  Category.find_or_create_by!(name: attrs[:name]) do |cat|
    cat.color = attrs[:color]
    cat.icon = attrs[:icon]
    cat.position = attrs[:position]
  end
end

puts "Seeded #{Category.count} categories"

# Create default user in development
if Rails.env.development?
  user = User.find_or_create_by!(email: "admin@example.com") do |u|
    u.password = "password123"
    u.password_confirmation = "password123"
  end
  puts "Default user: admin@example.com / password123"
end
