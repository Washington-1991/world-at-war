# db/seeds.rb

admin_email = ENV.fetch("WAW_ADMIN_EMAIL", nil)
admin_name  = ENV.fetch("WAW_ADMIN_NAME",  "Admin")
admin_birth_date = ENV.fetch("WAW_ADMIN_BIRTH_DATE", "1980-01-01")
admin_birth_country = ENV.fetch("WAW_ADMIN_BIRTH_COUNTRY", "FR")

if admin_email.present?
  admin = User.find_or_initialize_by(email: admin_email)

  admin.name = admin_name
  admin.birth_date = Date.parse(admin_birth_date)
  admin.birth_country = admin_birth_country
  admin.role = :admin

  if admin.save
    puts "✅ Admin ensured: #{admin.email}"
  else
    puts "❌ Admin seed failed: #{admin.errors.full_messages.join(", ")}"
  end
else
  puts "ℹ️  Admin seed skipped (set WAW_ADMIN_EMAIL to enable)"
end
