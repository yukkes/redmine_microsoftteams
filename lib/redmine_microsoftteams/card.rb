# frozen_string_literal: true

module RedmineMicrosoftteams
  # Builds the JSON payload posted to Microsoft Teams.
  module Card
    ESCAPES = {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      "\r" => "\n",
      '[' => '&#91;',
      ']' => '&#93;',
      '\\' => '&#92;',
      '~' => '&#126;',
      '{' => '&#123;',
      '}' => '&#125;',
      ':' => '&#58;'
    }.freeze
    ESCAPE_PATTERN = Regexp.union(ESCAPES.keys)

    MAX_SECTIONS_LENGTH = 14_000

    module_function

    def escape(msg)
      msg.to_s.gsub(ESCAPE_PATTERN, ESCAPES)
    end

    # Office 365 connector URLs contain "webhook" and take a message card.
    # Other URLs, e.g. of Workflows, take an Adaptive Card.
    def build(url, title, text, sections, facts)
      sections = limit_string_length(sections.to_s) if sections
      facts ||= {}
      if url.downcase.include?('webhook')
        message_card(title, text, sections, facts)
      else
        adaptive_card_message(title, text, sections, facts)
      end
    end

    def message_card(title, text, sections, facts)
      sections = sections ? escape_description(sections) : []
      sections << { facts: facts.map { |name, value| { name: name, value: value } } } if facts.any?

      msg = {}
      msg[:title] = title if title
      msg[:text] = text if text
      msg[:sections] = sections
      msg
    end

    def adaptive_card_message(title, text, sections, facts)
      body = []
      body << { type: 'TextBlock', text: title, weight: 'bolder', size: 'medium' } if title
      body << { type: 'TextBlock', text: text, wrap: true } if text
      body.concat(adaptive_text_blocks(sections)) if sections
      body << { type: 'FactSet', facts: facts.map { |name, value| { title: name, value: value } } } if facts.any?

      {
        type: 'message',
        attachments: [
          {
            contentType: 'application/vnd.microsoft.card.adaptive',
            content: { type: 'AdaptiveCard', version: '1.2', body: body, msteams: { width: 'full' } }
          }
        ]
      }
    end

    # Splits the text into entries and turns <pre> blocks into code blocks.
    def escape_description(msg)
      entries = []
      pos = 0
      while pos < msg.length
        pre_start = msg.index('<pre>', pos)
        pre_end = pre_start && find_end_of_pre(msg, pre_start)
        entries << { text: escape(msg[pos...pre_start]) } if pre_start && pre_start != pos
        unless pre_end
          entries << { text: escape(msg[(pre_start || pos)..-1]) }
          break
        end

        entries << { text: "```\r\n#{msg[(pre_start + 5)...(pre_end - 6)]}" }
        pos = pre_end
      end
      entries
    end

    # Returns the position after the </pre> tag closing the <pre> tag at pos.
    def find_end_of_pre(msg, pos)
      depth = 0
      while pos < msg.length
        if msg[pos, 5] == '<pre>'
          depth += 1
          pos += 5
        elsif msg[pos, 6] == '</pre>'
          depth -= 1
          return pos + 6 if depth.zero?

          pos += 6
        else
          pos += 1
        end
      end
      nil
    end

    def adaptive_text_blocks(text)
      parts = text.tr("\r", "\n").scan(%r{(?:<pre>(.*?)</pre>|(.*?))(?=<pre>|$)}m)
      parts.each_with_object([]) do |(pre, plain), blocks|
        if pre
          blocks << { type: 'TextBlock', text: pre.strip, wrap: true, fontType: 'monospace' }
        elsif !plain.empty?
          blocks << { type: 'TextBlock', text: plain.strip, wrap: true }
        end
      end
    end

    def limit_string_length(str)
      str.length > MAX_SECTIONS_LENGTH ? "#{str[0..MAX_SECTIONS_LENGTH]}..." : str
    end
  end
end
