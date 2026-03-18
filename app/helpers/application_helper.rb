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

  def category_label(category)
    return content_tag(:span, "Uncategorized", class: "text-gray-400 italic") unless category

    content_tag(:span, class: "inline-flex items-center") do
      content_tag(:span, "", class: "w-2 h-2 rounded-full mr-1.5", style: "background-color: #{category.color};") +
        category.name
    end
  end

  def filter_active?
    %i[account_id category_id type date_from date_to].any? { |k| params[k].present? }
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
