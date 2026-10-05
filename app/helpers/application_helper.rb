# Helpers for displaying IDR prices, durations and dates in Indonesian format.

module ApplicationHelper
  def format_idr(amount)
    "Rp #{number_with_delimiter(amount.to_i, delimiter: '.')}"
  end

  def format_duration(minutes)
    h, m = minutes.to_i.divmod(60)
    parts = []
    parts << "#{h} jam" if h.positive?
    parts << "#{m} menit" if m.positive?
    parts.join(" ")
  end

  def format_time_short(time)
    time.strftime("%H:%M")
  end

  def format_date_id(date)
    date.strftime("%d %b %Y")
  end

  def format_datetime_id(time)
    time.strftime("%d %b %Y, %H:%M")
  end

  def rating_stars(rating)
    full = rating.to_f.round
    ("★" * full) + ("☆" * (5 - full))
  end

  def avatar_placeholder(name, size: 10)
    letter = name.to_s[0].upcase
    colors = %w[bg-rose-500 bg-pink-500 bg-fuchsia-500 bg-purple-500 bg-indigo-500]
    color = colors[name.to_s.sum % colors.length]
    content_tag :div, letter, class: "flex items-center justify-center rounded-full #{color} text-white font-semibold",
                              style: "width: #{size * 4}px; height: #{size * 4}px"
  end

  def active_nav_link_class(path)
    current_page?(path) ? "nav-link-active" : "nav-link"
  end

  def breadcrumb(links = [])
    content_tag :nav, class: "text-sm text-neutral-500 mb-4" do
      links.each_with_index.map do |(label, path), i|
        separator = i.zero? ? "" : content_tag(:span, "›", class: "mx-2")
        link = path ? link_to(label, path, class: "hover:text-rose-500") : content_tag(:span, label, class: "text-neutral-800")
        separator + link
      end.join.html_safe
    end
  end
end
