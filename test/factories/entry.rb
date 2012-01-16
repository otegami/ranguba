# -*- coding: utf-8 -*-

FactoryGirl.define do
  sequence(:key_id)

  factory(:entry, :class => Ranguba::Entry) do
    ignore do
      type_label   {type}
      default_body {"This is the contents of the #{type_label} entry."}
    end

    key do
      "http://www.example.com/#{type}/#{FactoryGirl.generate(:key_id)}"
    end
    title       {"This is an #{type_label} entry!"}
    encoding    {"UTF-8"}
    category    {"test"}
    author      {"#{type_label} author"}
    modified_at {Time.parse("2011-01-01 00:00:00 +0900")}
    updated_at  {Time.parse("2010-01-01 00:00:00 +0900")}
    body        {default_body}
  end
end
