module ApplicationHelper
  def boolean(value, options = {})
    content_tag :span, class: "badge badge-#{value ? 'success' : 'danger'}" do
      content_tag :i, nil, class: "fa fa-#{value ? :check : :times}"
    end
  end

  def number_to_hour_minutes(number)
    time = ''
    if number > 86400
      days = (number / 86400).to_i
      number = number - days * 86400
      time = "#{days}g "
    end
    time += Time.at(number).utc.strftime("%Hh %Mmin %Ssec").to_s
  end

  def toggle(url, value, options = {})
    options.deep_merge!({ class: :'btn btn-secondary', data: { checkbox: true, disable: true, url: url } })
    if value
      yes = content_tag :span, (content_tag :i, nil, class: :'fa fa-check'), class: :'btn btn-success'
      no = link_to (content_tag :i, nil, class: :'fa fa-times'), '#', options
    else
      yes = link_to (content_tag :i, nil, class: :'fa fa-check'), '#', options
      no = content_tag :span, (content_tag :i, nil, class: :'fa fa-times'), class: :'btn btn-danger'
    end
    content_tag :div, class: :'btn-group btn-group-xs', data: { behaviour: :toggle } do
      "#{yes} #{no}".html_safe
    end
  end

  def toggle_is_active(resource, options = {})
    # Se c'è un confirm toggle_resource personalizzato prende quello altrimenti il generico confirm
    confirm = I18n.t("confirm.toggle_#{resource.class.name.downcase}", default: I18n::t('confirm.generic'))
    url_hash = { controller: resource.class.table_name, action: 'toggle_is_active', id: resource.id}
    url_hash.deep_merge!(options)
    if resource.aluan == false
      link_to (content_tag :i, nil, class: :'fa fa-times-circle'), url_for(url_hash), class: :'btn btn-sm btn-danger', data: { confirm: confirm, method: :patch }, title: I18n::t('actions.aluan_no')
    else
      link_to (content_tag :i, nil, class: :'fa fa-check-circle'), url_for(url_hash), class: :'btn btn-sm btn-success', data: { confirm: confirm, method: :patch }, title: I18n::t('actions.aluan_yes')
    end
  end
end
