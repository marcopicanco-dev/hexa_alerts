module ApplicationHelper
  FLAGS = {
    "BRA" => "🇧🇷", "MAR" => "🇲🇦", "NZL" => "🇳🇿", "EGY" => "🇪🇬",
    "ARG" => "🇦🇷", "ESP" => "🇪🇸", "FRA" => "🇫🇷", "POR" => "🇵🇹",
    "ENG" => "🏴\u{E0067 E0062 E0065 E006E E0067 E007F}", "NOR" => "🇳🇴"
  }.freeze

  def team_flag(team)
    return image_tag(team.flag_url, alt: "Bandeira de #{team.name}", class: "inline-block h-8 w-10 object-contain") if team.flag_url.present?

    FLAGS.fetch(team.fifa_code, "🏳️")
  end

  def match_status_label(match)
    { "scheduled" => "Agendado", "live" => "Ao vivo", "finished" => "Encerrado",
      "postponed" => "Adiado", "cancelled" => "Cancelado" }.fetch(match.status, match.status.humanize)
  end

  def country_flag(code)
    FLAGS.fetch(code, "🏳️")
  end

  def team_display_name(team)
    I18n.t("teams.#{team.fifa_code}", locale: :"pt-BR", default: team.name)
  end

  def event_kind_label(kind)
    I18n.t("event_kinds.#{kind}", locale: :"pt-BR", default: kind.humanize)
  end

  def match_stage_label(match)
    { "group" => "Fase de grupos", "group_stage" => "Fase de grupos",
      "round_of_32" => "16 avos de final", "round_of_16" => "Oitavas de final",
      "quarterfinals" => "Quartas de final", "quarter_finals" => "Quartas de final",
      "semifinals" => "Semifinal", "semi_finals" => "Semifinal",
      "3rd_place_match" => "Disputa do 3º lugar", "third_place" => "Disputa do 3º lugar",
      "final" => "Final" }.fetch(match.stage, "Copa do Mundo")
  end
end
