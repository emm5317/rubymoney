module ApplicationHelper
  include Pagy::Frontend

  def import_status_badge(status)
    css = case status.to_s
          when "completed"  then "bg-green-100 text-green-800"
          when "failed"     then "bg-red-100 text-red-800"
          when "processing" then "bg-blue-100 text-blue-800"
          when "previewing" then "bg-yellow-100 text-yellow-800"
          else "bg-gray-100 text-gray-800"
          end
    content_tag(:span, status.to_s.titleize, class: "px-2 py-1 text-xs rounded-full #{css}")
  end

  def transaction_status_badge(status)
    css = case status.to_s
          when "cleared"     then "bg-green-100 text-green-800"
          when "reconciled"  then "bg-blue-100 text-blue-800"
          when "pending"     then "bg-yellow-100 text-yellow-800"
          else "bg-gray-100 text-gray-800"
          end
    content_tag(:span, status.to_s.titleize, class: "px-2 py-1 text-xs rounded-full #{css}")
  end
end
