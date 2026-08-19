module ApplicationHelper
  def money(cents)
    sign = cents.negative? ? "-" : ""
    "#{sign}$#{format('%.2f', cents.abs / 100.0)}"
  end
end
