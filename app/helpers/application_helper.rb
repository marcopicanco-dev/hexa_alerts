module ApplicationHelper
  FLAGS = {
    "BRA" => "🇧🇷", "MAR" => "🇲🇦", "NZL" => "🇳🇿", "EGY" => "🇪🇬",
    "ARG" => "🇦🇷", "ESP" => "🇪🇸", "FRA" => "🇫🇷", "POR" => "🇵🇹"
  }.freeze

  def team_flag(team)
    return image_tag(team.flag_url, alt: "Bandeira de #{team.name}", class: "inline-block h-8 w-10 object-contain") if team.flag_url.present?

    FLAGS.fetch(team.fifa_code, "🏳️")
  end

  def match_status_label(match)
    { "scheduled" => "Agendado", "live" => "Ao vivo", "finished" => "Encerrado",
      "postponed" => "Adiado", "cancelled" => "Cancelado" }.fetch(match.status, match.status.humanize)
  end
end
