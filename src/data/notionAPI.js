// Cole o token que funcionou no teste
const NOTION_TOKEN = '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';
const DATABASE_ID = '25385992c72880298c80e801dbd64b7f';
const NOTION_API_URL = 'https://api.notion.com/v1';

export const fetchNotionEvents = async () => {
  try {
    console.log('🚀 Buscando eventos do Notion...');
    
    const response = await fetch(`${NOTION_API_URL}/databases/${DATABASE_ID}/query`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${NOTION_TOKEN}`,
        'Content-Type': 'application/json',
        'Notion-Version': '2022-06-28',
      },
      body: JSON.stringify({
        sorts: [
          {
            property: 'Data',
            direction: 'ascending'
          }
        ]
      })
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const data = await response.json();
    console.log(`✅ ${data.results.length} eventos carregados!`);

    const events = data.results.map((event, eventIndex) => {
      const properties = event.properties;
      
      // 🔍 DEBUG: Mostrar TODOS os nomes de campos do Notion
      console.log(`\n🔍 EVENTO ${eventIndex + 1} - Campos disponíveis:`, Object.keys(properties));
      
      // 📅 DATA E HORA - CORRIGIDO PARA UTC
      const dateObj = properties['Data']?.date;
      let eventDate = '';
      let eventTime = '20:00';
      
      if (dateObj?.start) {
        const dateString = dateObj.start;
        
        if (dateString.includes('T')) {
          const datePart = dateString.split('T')[0];
          eventDate = datePart;
          
          const timePart = dateString.split('T')[1];
          if (timePart) {
            const [hours, minutes] = timePart.split(':');
            eventTime = `${hours}:${minutes}`;
          }
        } else {
          eventDate = dateString;
        }
        
        console.log(`📅 Data do evento: ${eventDate} às ${eventTime}`);
      }

      // 📝 NOME DO EVENTO
      const eventName = properties['Nome']?.title?.[0]?.plain_text || 'Evento sem nome';
      console.log(`📌 Nome: ${eventName}`);
      
      // 🏷️ TAGS (multi_select)
      const tags = properties['Tags']?.multi_select || [];
      const tagNames = tags.map(tag => tag.name).join(', ');
      
      // 👤 ORGANIZADOR (people)
      const organizadores = properties['Organizador']?.people || [];
      const organizador = organizadores[0]?.name || 'Organizador não definido';
      
      // 📍 SEDE/LOCAL (select)
      const sede = properties['Sede']?.select?.name || 'Local não definido';
      
      // 💰 PREÇO (number)
      const preco = properties['Preço']?.number || 0;
      
      // ✨ DESCRIÇÃO COMPLETA - DEBUG COMPLETO
      let descricao = '';
      let descricaoCompleta = [];
      
      // 🔍 DEBUG: Verificar se existe campo de descrição
      console.log(`\n🔍 DEBUG DESCRIÇÃO:`);
      console.log(`   - properties['Descrição']:`, properties['Descrição']);
      console.log(`   - properties['Description']:`, properties['Description']);
      console.log(`   - Todos os campos:`, Object.keys(properties).filter(k => k.toLowerCase().includes('desc')));
      
      // Tenta 'Descrição' (português)
      if (properties['Descrição']?.rich_text && properties['Descrição'].rich_text.length > 0) {
        console.log(`✅ ENCONTRADO: Campo 'Descrição' com ${properties['Descrição'].rich_text.length} blocos`);
        descricaoCompleta = properties['Descrição'].rich_text;
        descricao = properties['Descrição'].rich_text
          .map(block => block.plain_text)
          .join('\n');
      }
      // Tenta 'Description' (inglês)
      else if (properties['Description']?.rich_text && properties['Description'].rich_text.length > 0) {
        console.log(`✅ ENCONTRADO: Campo 'Description' com ${properties['Description'].rich_text.length} blocos`);
        descricaoCompleta = properties['Description'].rich_text;
        descricao = properties['Description'].rich_text
          .map(block => block.plain_text)
          .join('\n');
      }
      // Fallback
      else {
        console.log(`⚠️ Nenhum campo de descrição encontrado. Usando fallback.`);
        descricao = `${tagNames ? `Categorias: ${tagNames}. ` : ''}Organizado por ${organizador}`;
      }
      
      console.log(`📝 Descrição completa - Total de blocos: ${descricaoCompleta.length}`);
      if (descricaoCompleta.length > 0) {
        console.log(`   Conteúdo do primeiro bloco:`, descricaoCompleta[0]);
        console.log(`   Annotations:`, descricaoCompleta[0].annotations);
      }
      
      // 📸 IMAGEM (files)
      let imagemUrl = '';
      if (properties['Imagem']?.files?.[0]) {
        const file = properties['Imagem'].files[0];
        imagemUrl = file.file?.url || file.external?.url || '';
        console.log(`📸 Imagem encontrada: ${imagemUrl ? 'Sim' : 'Não'}`);
      } else if (properties['Capa']?.files?.[0]) {
        const file = properties['Capa'].files[0];
        imagemUrl = file.file?.url || file.external?.url || '';
      }
      
      // 🔗 URL DO EVENTO
      const eventUrl = properties['Página do evento']?.url || event.public_url || '';
      
      // ✅ STATUS (select)
      const status = properties['Status']?.select?.name === 'Esgotado' ? 'sold_out' : 'available';
      
      const eventObject = {
        id: event.id,
        name: eventName,
        date: eventDate,
        time: eventTime,
        price: preco,
        location: sede,
        status: status,
        description: descricao,
        descricaoCompleta: descricaoCompleta,
        tags: tagNames,
        organizer: organizador,
        image: imagemUrl,
        url: eventUrl
      };
      
      console.log(`✅ Evento processado:`, eventObject);
      
      return eventObject;
    })
    .filter(event => event.date)
    .filter(event => {
      const eventDate = new Date(event.date + 'T00:00:00');
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      return eventDate >= today;
    });

    console.log(`📅 ${events.length} eventos futuros processados!`);
    console.log(`\n🎉 FINAL - Todos os eventos:`, events);
    return events;

  } catch (error) {
    console.error('💥 Erro ao buscar eventos do Notion:', error);
    return [];
  }
};

export const getMarkedDatesFromNotion = (events) => {
  const marked = {};
  
  events.forEach(event => {
    if (event.date) {
      marked[event.date] = {
        marked: true,
        dotColor: '#5166C6',
        selectedColor: '#5166C6'
      };
    }
  });
  
  return marked;
};

export const getEventsForDateFromNotion = (events, date) => {
  return events.filter(event => event.date === date);
};

export const getAllEventsFromNotion = (events) => {
  return events.sort((a, b) => new Date(a.date) - new Date(b.date));
};
