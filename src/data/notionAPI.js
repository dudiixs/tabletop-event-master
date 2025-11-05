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

    const events = data.results.map(event => {
      const properties = event.properties;
      
      // 📅 DATA E HORA - CORRIGIDO PARA UTC
      const dateObj = properties['Data']?.date;
      let eventDate = '';
      let eventTime = '20:00';
      
      if (dateObj?.start) {
        // ✨ CORREÇÃO: Pegar apenas a parte da data (sem considerar timezone)
        const dateString = dateObj.start;
        
        // Se vier com hora (2024-11-11T19:00:00), pega só a data
        if (dateString.includes('T')) {
          const datePart = dateString.split('T')[0]; // "2024-11-11"
          eventDate = datePart;
          
          // Extrair hora
          const timePart = dateString.split('T')[1]; // "19:00:00"
          if (timePart) {
            const [hours, minutes] = timePart.split(':');
            eventTime = `${hours}:${minutes}`;
          }
        } else {
          // Se vier apenas a data (2024-11-11)
          eventDate = dateString;
        }
        
        console.log(`📅 Data do evento: ${eventDate} às ${eventTime}`);
      }

      // 📝 NOME DO EVENTO
      const eventName = properties['Nome']?.title?.[0]?.plain_text || 'Evento sem nome';
      
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
      
      // 📝 DESCRIÇÃO COMPLETA (rich_text ou text)
      let descricao = '';
      if (properties['Descrição']?.rich_text?.[0]?.plain_text) {
        descricao = properties['Descrição'].rich_text[0].plain_text;
      } else if (properties['Descrição']?.text?.[0]?.plain_text) {
        descricao = properties['Descrição'].text[0].plain_text;
      } else {
        descricao = `${tagNames ? `Categorias: ${tagNames}. ` : ''}Organizado por ${organizador}`;
      }
      
      // 📸 IMAGEM (files)
      let imagemUrl = '';
      if (properties['Imagem']?.files?.[0]) {
        const file = properties['Imagem'].files[0];
        imagemUrl = file.file?.url || file.external?.url || '';
      } else if (properties['Capa']?.files?.[0]) {
        const file = properties['Capa'].files[0];
        imagemUrl = file.file?.url || file.external?.url || '';
      }
      
      // 🔗 URL DO EVENTO
      const eventUrl = properties['Página do evento']?.url || event.public_url || '';
      
      // ✅ STATUS (select)
      const status = properties['Status']?.select?.name === 'Esgotado' ? 'sold_out' : 'available';
      
      return {
        id: event.id,
        name: eventName,
        date: eventDate,  // ✨ Agora retorna a data CORRETA
        time: eventTime,
        price: preco,
        location: sede,
        status: status,
        description: descricao,
        tags: tagNames,
        organizer: organizador,
        image: imagemUrl,
        url: eventUrl
      };
    })
    .filter(event => event.date)
    .filter(event => {
      // ✨ COMPARAÇÃO DE DATA CORRIGIDA
      const eventDate = new Date(event.date + 'T00:00:00');
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      return eventDate >= today;
    });

    console.log(`📅 ${events.length} eventos futuros processados!`);
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
